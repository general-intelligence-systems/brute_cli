# frozen_string_literal: true

require "reline"
require "brute_cli/styles"
require "brute_cli/question_screen"

module BruteCLI
  # REPL wraps an Execution with an interactive read-eval-print loop:
  # Reline prompt, Tab-based agent cycling, slash commands, fzf file picking,
  # and banner display.
  #
  # For non-interactive (pipe / single-prompt) use, use Execution directly.
  class REPL
    # Mapping of provider name to the env var that indicates it's configured.
    PROVIDER_ENV_KEYS = {
      "anthropic"   => "ANTHROPIC_API_KEY",
      "openai"      => "OPENAI_API_KEY",
      "gemini"      => "GEMINI_API_KEY",
      "azure"       => "AZURE_API_KEY",
      "bedrock"     => "AWS_ACCESS_KEY_ID",
      "deepseek"    => "DEEPSEEK_API_KEY",
      "mistral"     => "MISTRAL_API_KEY",
      "ollama"      => "OLLAMA_API_KEY",
      "openrouter"  => "OPENROUTER_API_KEY",
      "perplexity"  => "PERPLEXITY_API_KEY",
      "xai"         => "XAI_API_KEY",
    }.freeze

    # Returns an array of provider name strings that have API keys configured.
    # Ollama is always included (it doesn't strictly require a key for local use).
    def self.configured_providers
      configured = PROVIDER_ENV_KEYS.select { |_name, key| ENV[key] && !ENV[key].empty? }.keys
      configured << "ollama" unless configured.include?("ollama")
      configured.sort
    end

    def initialize(options = {})
      @execution = Execution.new(options)
      @terminal = @execution.terminal
      @saved_provider = nil  # stashed LLM provider symbol when in shell-mode agent
    end

    # Start the interactive REPL loop.
    def run
      @execution.ensure_session!

      Banner.new(
        terminal:     @terminal,
        session_id:   @execution.session_id,
        session_path: @execution.session_path,
      )

      @execution.resolve_provider_info
      @input = UserInput.new(@terminal)

      loop do
        status = build_prompt_status
        result = @input.read_prompt(status)

        case result
        when nil
          break
        when ->(r) { r[:type] == :cycle_agent }
          handle_cycle_agent(result[:direction])
          @input.refresh_model_line(build_prompt_status)
          next
        when ->(r) { r[:type] == :input }
          text = result[:text]
          next if text.empty?
          break if %w[exit quit].include?(text)

          if Commands.match?(text)
            break if handle_command(text) == :exit
            next
          end

          @execution.run(text)
        end
      end
    rescue Interrupt
      @terminal.buffer << ""
    end

    private

    def build_prompt_status
      PromptStatus.new(
        provider_name: @execution.provider_name,
        model_short:   @execution.model_short,
        current_agent: @execution.current_agent,
      )
    end

    # ── Agent cycling ──

    def handle_cycle_agent(direction)
      agents = Execution::AGENTS
      shell_agents = Execution::SHELL_AGENTS
      step = direction == :backward ? -1 : 1
      idx = (agents.index(@execution.current_agent) + step) % agents.size
      new_agent = agents[idx]

      if (shell_model = shell_agents[new_agent])
        activate_shell_agent!(shell_model)
      else
        restore_llm_provider!
      end

      @execution.current_agent = new_agent
      reset_agent!
      @execution.resolve_provider_info
    end

    def select_model(model_id)
      @execution.selected_model = model_id
      reset_agent!
      @execution.resolve_provider_info
      @models_cache = nil
    end

    def select_provider(provider_name)
      Brute.provider = provider_name.to_sym
      @execution.selected_model = nil
      reset_agent!
      @execution.resolve_provider_info
      @models_cache = nil
      provider_name
    end

    # Fetch available chat models from the current provider via RubyLLM.
    # Results are cached to avoid repeated API calls; cleared on provider change.
    def fetch_models
      return @models_cache if @models_cache

      provider = Brute.provider
      return [] unless provider

      begin
        Brute.config # ensure RubyLLM is configured
        all = RubyLLM.models.all
        provider_str = provider.to_s
        @models_cache = all
          .select { |m| m.provider.to_s == provider_str && m.type.to_s == "chat" }
          .map { |m| m.id.to_s }
          .sort
      rescue => e
        @terminal.buffer << "Failed to fetch models: #{e.message}".colorize(ERROR_FG)
        @models_cache = []
      end

      @models_cache
    end

    # Save the current LLM provider symbol when entering a shell-mode agent.
    def activate_shell_agent!(shell_model)
      current = Brute.provider
      @saved_provider ||= current
      @execution.selected_model = shell_model
    end

    # Restore the saved LLM provider symbol when leaving a shell-mode agent.
    def restore_llm_provider!
      if @saved_provider
        Brute.provider = @saved_provider
        @saved_provider = nil
        @execution.selected_model = nil
      end
    end

    # Force the agent to be recreated on next ensure_agent! call.
    def reset_agent!
      @execution.agent = nil
    end

    def compact_conversation
      nil
    end

    # ── Commands ──

    def handle_command(input)
      entry = Commands.find(input)
      unless entry
        @terminal.buffer << "Unknown command: #{input.split(/\s+/).first}".colorize(ERROR_FG)
        @terminal.buffer << "Type /help for available commands.".colorize(DIM)
        return nil
      end

      send(entry.method_name)
    end

    def cmd_help
      @terminal.buffer << @terminal.separator
      @terminal.buffer << "Available commands:".colorize(ACCENT_BOLD)
      @terminal.buffer << ""
      Commands::REGISTRY.each do |entry|
        @terminal.buffer << "  #{entry.name.ljust(12).colorize(ACCENT)}  #{entry.description.colorize(DIM)}"
      end
      @terminal.buffer << @terminal.separator
      nil
    end

    def cmd_exit
      :exit
    end

    def cmd_compact
      tokens = compact_conversation
      if tokens
        @terminal.buffer << "Compacting conversation...".colorize(DIM)
        @terminal.buffer << "Current token count: #{tokens}".colorize(DIM)
        @terminal.buffer << "Manual compaction not yet implemented.".colorize(DIM)
      else
        @terminal.buffer << "No active conversation to compact.".colorize(DIM)
      end
      nil
    end

    def cmd_menu
      menu = build_main_menu
      result = menu.call(:main)

      case result
      when :exit
        return :exit
      when Array
        action, *args = result
        handle_menu_action(action, *args)
      end

      nil
    end

    def cmd_model
      menu = build_main_menu
      result = menu.call(:models)

      if result.is_a?(Array)
        action, *args = result
        handle_menu_action(action, *args)
      end

      nil
    end

    def cmd_provider
      menu = build_main_menu
      result = menu.call(:providers)

      if result.is_a?(Array)
        action, *args = result
        handle_menu_action(action, *args)
      end

      nil
    end

    def handle_menu_action(action, *args)
      case action
      when :set_model
        model_id = args.first
        select_model(model_id)
        @terminal.buffer << @terminal.separator
        @terminal.buffer << "Model changed to: #{model_id.colorize(ACCENT)}"
        @terminal.buffer << @terminal.separator
      when :set_provider
        provider_name = args.first
        select_provider(provider_name)
        @terminal.buffer << @terminal.separator
        @terminal.buffer << "Provider changed to: #{provider_name.colorize(ACCENT)}"
        @terminal.buffer << "Select a model:".colorize(DIM)
        cmd_model
      end
    end

    # ── Menu Builder ──

    def build_main_menu
      repl = self
      execution = @execution

      FzfMenu.new do
        menu :main, "Brute" do
          choice "Change Model",    :models
          choice "Change Provider", :providers
          choice "Help",            :help_display
          choice "Exit Menu",       nil
        end

        menu :help_display, "Help" do
          choice "Back", :main
        end

        menu(:models, "Select Model") do |m|
          models = repl.send(:fetch_models)
          current = execution.model_name

          models.each do |id|
            label = id == current ? "#{id} (current)" : id
            m.choice label, [:set_model, id]
          end

          m.choice "Back", :main
        end

        menu(:providers, "Select Provider") do |m|
          configured = BruteCLI::REPL.configured_providers
          current = execution.provider_name

          configured.each do |name|
            label = name == current ? "#{name} (current)" : name
            m.choice label, [:set_provider, name]
          end

          m.choice "Back", :main
        end
      end
    end
  end
end
