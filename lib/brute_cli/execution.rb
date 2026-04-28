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
  # an agent, streaming output to the terminal.  It owns the agent lifecycle
  # and stats rendering; streaming/rendering is handled by CLIEventHandler.
  #
  # Use directly for non-interactive (pipe / single-prompt) mode:
  #
  #   BruteCLI::Execution.new(options).run(prompt)
  #
  # Or let BruteCLI::REPL wrap it for interactive use.
  class Execution
    AGENTS = %w[build plan bash ruby python nix].freeze

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

    attr_reader :current_agent, :provider_name, :model_name, :terminal
    attr_accessor :agent
    attr_writer :selected_model, :current_agent

    # Expose session path for Banner display (read-only).
    def session_path
      @session&.path
    end

    def initialize(options = {})
      @options = options
      @terminal = options[:terminal] || Terminal.new
      @current_agent = AGENTS.first
      @agent = nil
      @session = nil
      @selected_model = nil    # user-chosen model override (nil = provider default)
      @streamer = StreamFormatter.new(output: @terminal.buffer.io, width: @terminal.width)
      spinner_class = options[:spinner] || BruteCLI.config.spinner
      @spinner = spinner_class.new(output: @terminal.buffer.io)
      @event_handler = nil
    end

    # Run a single prompt against the agent.  This is the primary public API.
    def run(prompt)
      ensure_agent!
      execute(prompt)
    end

    def execute(prompt)
      @event_handler = build_event_handler
      @event_handler.reset!
      @event_handler.start_spinner

      begin
        @session.user(prompt)
        env = @agent.call(@session, events: @event_handler)
        @event_handler.merge_metadata!(env[:metadata])
      rescue Interrupt
        @event_handler.stop_spinner
        @event_handler.flush_content
        @terminal.buffer << "Aborted.".colorize(DIM)
        print_stats_bar
        return
      rescue => e
        @event_handler.stop_spinner
        @event_handler.flush_content
        print_error(e)
        print_stats_bar
        return
      end

      @event_handler.stop_spinner
      @event_handler.flush_content
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
        path = build_session_path(@options[:session_id])
        if File.exist?(path)
          @session = Brute::Session.from_jsonl(path)
        else
          @session = Brute::Session.new(path: path)
        end
      else
        id = SecureRandom.hex(8)
        @session = Brute::Session.new(path: build_session_path(id))
      end
    end

    def ensure_agent!
      return if @agent

      ensure_session!
      resolve_provider_info
      @agent = build_agent
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

      def build_session_path(id)
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
          model: @model_name,
          tools: Brute::Tools::ALL,
        ) do
          use Brute::Middleware::SystemPrompt
          use Brute::Middleware::Tracing, logger: logger
          use Brute::Middleware::ToolResultLoop
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
          use Brute::Middleware::ToolCall
          run ShellCallTerminal.new(shell_provider)
        end
      end

      def build_event_handler
        CLIEventHandler.new(
          Brute::Pipeline::NullSink.new,
          terminal: @terminal,
          spinner:  @spinner,
          streamer: @streamer,
        )
      end

      # ── Stats ──

      def print_stats_bar
        metadata = @event_handler&.metadata || {}
        @terminal.buffer << @terminal.separator
        @terminal.buffer << BufferOutput::StatsBar.new(metadata, width: @terminal.width)
        @terminal.buffer << @terminal.separator(thick: true)
      end

      # ── Error ──

      def print_error(err)
        @terminal.buffer << BufferOutput::Error.new(err)
      end

      # ── Provider Helpers ──

      PROVIDER_DEFAULT_MODELS = {
        anthropic:  "claude-sonnet-4-20250514",
        openai:     "gpt-4.1",
        gemini:     "gemini-2.5-flash",
        deepseek:   "deepseek-chat",
        mistral:    "mistral-large-latest",
        openrouter: "anthropic/claude-sonnet-4-20250514",
        xai:        "grok-3",
      }.freeze

      def default_model_for(provider_sym)
        PROVIDER_DEFAULT_MODELS[provider_sym&.to_sym]
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
