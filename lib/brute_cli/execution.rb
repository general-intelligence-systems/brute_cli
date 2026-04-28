# frozen_string_literal: true

require "logger"
require "io/console"
require "json"
require "pp"
require "securerandom"
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

    # Default sessions directory: ~/.brute/sessions/
    SESSIONS_DIR = File.join(Dir.home, ".brute", "sessions")

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
      @event_handler = nil
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
        @event_handler = build_event_handler
        @session.user(prompt)
        @agent.call(@session, events: @event_handler)
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
        @provider_name = provider.to_s
        @model_name = @selected_model || default_model_for(provider)
      end
    end

    def model_short
      @model_name&.sub(/^claude-/, "")&.sub(/-\d{8}$/, "") || @model_name
    end

    # ── Agent ──

    def ensure_session!
      return if @session

      if @options[:session_id]
        path = session_path(@options[:session_id])
        if File.exist?(path)
          @session = Brute::Session.from_jsonl(path)
        else
          @session = Brute::Session.new(path: path)
        end
      else
        id = SecureRandom.hex(8)
        @session = Brute::Session.new(path: session_path(id))
      end
    end

    def ensure_agent!
      return if @agent

      ensure_session!
      resolve_provider_info
      @agent = build_agent
    end

    def detect_width
      TTY::Screen.width
    end

    # Session ID derived from the session path.
    def session_id
      return @options[:session_id] if @options[:session_id]
      return nil unless @session&.path
      File.basename(File.dirname(@session.path))
    end

    # List saved sessions by scanning the sessions directory.
    def self.list_sessions
      dir = SESSIONS_DIR
      return [] unless Dir.exist?(dir)

      Dir.glob(File.join(dir, "*", "session.jsonl")).map do |path|
        {
          id: File.basename(File.dirname(path)),
          path: path,
          mtime: File.mtime(path),
        }
      end.sort_by { |s| s[:mtime] }.reverse
    end

    private

      # ── Session Path ──

      def session_path(id)
        File.join(SESSIONS_DIR, id, "session.jsonl")
      end

      # ── Agent Builder ──

      def build_agent
        if (shell_model = SHELL_AGENTS[@current_agent])
          build_shell_agent(shell_model)
        else
          build_llm_agent
        end
      end

      def build_llm_agent
        logger = Logger.new(File::NULL)

        Brute::Agent.new(
          provider: Brute.provider,
          model: @selected_model,
          tools: Brute::Tools::ALL,
        ) do
          use Brute::Middleware::SystemPrompt
          use Brute::Middleware::Tracing, logger: logger
          use Brute::Middleware::ToolResultLoop
          use Brute::Middleware::MaxIterations
          use Brute::Middleware::ToolCall
          run Brute::Middleware::LLMCall.new
        end
      end

      def build_shell_agent(shell_model)
        shell_provider = Brute::Providers::Shell.new

        Brute::Agent.new(
          provider: :shell,
          model: shell_model,
          tools: [Brute::Tools::Shell],
        ) do
          use Brute::Middleware::ToolResultLoop
          use Brute::Middleware::MaxIterations, max_iterations: 2
          use Brute::Middleware::ToolCall
          run ShellCallTerminal.new(shell_provider)
        end
      end

      # Build the event handler for this call, wired to this Execution.
      def build_event_handler
        CLIEventHandler.new(Brute::Pipeline::NullSink.new, execution: self)
      end

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
      # Called by CLIEventHandler when events arrive from the agent pipeline.
      # All callbacks fire sequentially — no synchronization needed.
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
        metadata = @event_handler&.metadata || {}
        puts BufferOutput::Separator.new(width: @width) unless @last_output == :separator
        puts BufferOutput::StatsBar.new(metadata, width: @width)
        puts BufferOutput::Separator.new(width: @width, thick: true)
      end

      # ── Error ──

      def print_error(err)
        puts BufferOutput::Error.new(err)
      end

      # ── Provider Helpers ──

      def default_model_for(provider_sym)
        # Use RubyLLM to look up the default model for a provider if possible.
        # Falls back to nil (let the provider decide).
        nil
      end

      # ── Shell Agent Terminal ──
      # A terminal middleware that uses Brute::Providers::Shell instead of
      # RubyLLM::Provider.resolve. Mimics LLMCall but delegates to the
      # Shell pseudo-provider.

      class ShellCallTerminal
        def initialize(shell_provider)
          @shell = shell_provider
        end

        def call(env)
          response = @shell.complete(
            env[:messages].to_a,
            model: env[:model],
            tools: env[:tools],
          )

          response.messages.each do |msg|
            env[:messages] << msg
          end

          env
        end
      end
  end
end
