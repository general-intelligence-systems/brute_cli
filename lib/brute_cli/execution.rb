# frozen_string_literal: true

require "logger"
require "io/console"
require "json"
require "pp"
require "brute_cli/styles"
require "brute_cli/phase"
require "brute_cli/tool_output"

module BruteCLI
  # Execution encapsulates running a single prompt (or repeated prompts) against
  # an agent, streaming output to the terminal.  It owns the agent lifecycle,
  # streaming callbacks, spinner, and stats rendering.
  #
  # Use directly for non-interactive (pipe / single-prompt) mode:
  #
  #   BruteCLI::Execution.new(options).run(prompt)
  #
  # Or let BruteCLI::REPL wrap it for interactive use.
  class Execution
    AGENTS = %w[build plan bash ruby python nix].freeze

    SAVE_CURSOR    = "\e7"
    RESTORE_CURSOR = "\e8"
    CLEAR_TO_END   = "\e[J"

    # Shell-mode agents: agent name -> shell interpreter (model name).
    # These agents use the Shell provider instead of the current LLM provider.
    SHELL_AGENTS = {
      "bash"   => "bash",
      "ruby"   => "ruby",
      "python" => "python",
      "nix"    => "nix",
    }.freeze

    attr_reader :current_agent, :provider_name, :model_name
    attr_accessor :agent
    attr_writer :selected_model, :current_agent

    def initialize(options = {})
      @options = options
      @current_agent = AGENTS.first
      @agent = nil
      @session = nil
      @selected_model = nil    # user-chosen model override (nil = provider default)
      @width = TTY::Screen.width
      @streamer = StreamFormatter.new(width: @width)
      spinner_class = options[:spinner] || BruteCLI.config.spinner
      @spinner = spinner_class.new
      @last_output = nil  # :separator, :content, or :tool — used to deduplicate separators
      @current_phase = nil
    end

    # Run a single prompt against the agent.  This is the primary public API.
    def run(prompt)
      ensure_agent!
      execute(prompt)
    end

    def execute(prompt)
      @current_phase = nil
      @streamer.reset
      @last_output = nil

      start_spinner

      begin
        @agent.run(prompt)
      rescue Interrupt
        stop_spinner
        flush_content
        puts "Aborted.".colorize(DIM)
        print_stats_bar
        return
      rescue => e
        stop_spinner
        flush_content
        print_error(e)
        print_stats_bar
        return
      end

      stop_spinner
      flush_content
      print_stats_bar
    end


    # ── Provider ──

    def resolve_provider_info
      if (shell_model = SHELL_AGENTS[@current_agent])
        @provider_name = "shell"
        @model_name = shell_model
      else
        provider = Brute.provider rescue nil
        @provider_name = provider&.name&.to_s
        @model_name = @selected_model || provider&.default_model&.to_s
      end
    end

    def model_short
      @model_name&.sub(/^claude-/, "")&.sub(/-\d{8}$/, "") || @model_name
    end

    # ── Agent ──

    def ensure_session!
      @session ||= Brute::Session.new(id: @options[:session_id])
    end

    def ensure_agent!
      return if @agent

      ensure_session!

      @agent = Brute.agent(
        cwd: @options[:cwd] || Dir.pwd,
        model: @selected_model,
        agent_name: @current_agent,
        session: @session,
        logger: Logger.new(File::NULL),
        on_content:          method(:on_content),
        on_reasoning:        method(:on_reasoning),
        on_tool_call_start:  method(:on_tool_call_start),
        on_tool_result:      method(:on_tool_result),
        # on_question: disabled until bubbletea terminal integration is fixed
      )
      @session.restore(@agent.context) if @options[:session_id]
    end

    def detect_width
      TTY::Screen.width
    end

    private

      # ── Spinner ──

      def start_spinner
        stop_spinner

        unless @last_output == :separator
          puts BufferOutput::Separator.new(width: @width)
          @last_output = :separator
        end

        @spinner.start
      end

      def stop_spinner
        if @spinner.spinning?
          @spinner.stop
        end
      end

      # ── Callbacks ──
      #
      # All callbacks fire sequentially on the same thread — no
      # synchronization needed.  The orchestrator guarantees:
      #
      #   on_content* → on_tool_call_start → on_tool_result* → (repeat)
      #

      def on_content(text)
        stop_spinner
        unless @current_phase.is_a?(Phase::ContentPhase)
          puts BufferOutput::Separator.new(width: @width) unless @last_output == :separator
          @current_phase = Phase::ContentPhase.new(@streamer)
        end
        @current_phase.append(text)
        @last_output = :content
      end

      def on_reasoning(_text); end

      # Receives the full batch of tool calls for this LLM turn.
      # Renders all tool call headers upfront.
      def on_tool_call_start(calls)
        stop_spinner
        flush_content

        @current_phase = Phase::ToolPhase.new(calls)

        puts BufferOutput::Separator.new(width: @width) unless @last_output == :separator
        print SAVE_CURSOR
        render_tool_phase
        @last_output = :tool

        start_spinner
      end

      # Fires once per tool as each completes.
      # Re-renders the entire tool phase block.
      def on_tool_result(name, result)
        stop_spinner

        if @current_phase.is_a?(Phase::ToolPhase)
          @current_phase.resolve(name, result)

          print RESTORE_CURSOR
          print CLEAR_TO_END
          render_tool_phase
          @last_output = :tool
          start_spinner
        end
      end

      # TODO: Interactive question forms are disabled while the bubbletea
      # terminal integration is being worked on. For now, auto-select the
      # first option for each question so the agent can continue.
      def on_question(questions, reply_queue)
        answers = questions.map do |q|
          q = q.respond_to?(:transform_keys) ? q.transform_keys(&:to_s) : q
          options = (q["options"] || []).map { |o| o.respond_to?(:transform_keys) ? o.transform_keys(&:to_s) : o }
          first = options.first
          first ? [first["label"].to_s] : []
        end

        reply_queue.push(answers)
      end

      # ── Output ──

      def flush_content
        if @current_phase.is_a?(Phase::ContentPhase)
          @current_phase.finish
          @last_output = :content unless @current_phase.empty?
        end
      end

      # Render every tool call in the current ToolPhase.
      # Resolved calls show header + body + error; pending calls show header only.
      def render_tool_phase
        @current_phase.tool_calls.each do |call|
          puts ToolOutput.for(call, width: @width)
        end
      end

      def render_markdown(text)
        BruteCLI::Bat.markdown_mode(text.strip, width: @width)
      end

      # ── Stats ──

      def print_stats_bar
        metadata = @agent&.env&.dig(:metadata) || {}
        puts BufferOutput::Separator.new(width: @width) unless @last_output == :separator
        puts BufferOutput::StatsBar.new(metadata, width: @width)
        puts BufferOutput::Separator.new(width: @width, thick: true)
      end

      # ── Error ──

      def print_error(err)
        puts BufferOutput::Error.new(err)
      end
    end
end
