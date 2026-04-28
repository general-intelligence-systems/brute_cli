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
      @saved_provider = nil  # stashed LLM provider symbol when in shell-mode agent
    end

    # Start the interactive REPL loop.
    def run
      @execution.ensure_session!
      print_banner
      @execution.resolve_provider_info
      setup_reline

      loop do
        result = read_prompt
        break if result.nil?
        next if result.empty?
        break if %w[exit quit].include?(result)

        # Slash command dispatch
        if Commands.match?(result)
          action = handle_command(result)
          break if action == :exit
          next
        end

        @execution.run(result)
      end
    rescue Interrupt
      puts
    end

    private

    # ── Reline ──

    def setup_reline
      Reline.autocompletion = true
      Reline.completion_append_character = " "
      Reline.completion_proc = method(:complete_input)

      Reline.prompt_proc = proc { |lines|
        prompt_text = current_prompt
        continuation = ">".rjust(prompt_text.length)
        lines.map.with_index do |_, i|
          i == 0 ? prompt_text.colorize(ACCENT_BOLD) + " " : continuation.colorize(DIM) + " "
        end
      }

      # Force Reline's config to load now (reads inputrc, registers ANSI
      # default key bindings).  Without this, the defaults are lazily
      # applied on the first readmultiline call and overwrite our overrides.
      unless Reline.core.config.loaded?
        Reline.core.config.read
        Reline::IOGate.set_default_key_bindings(Reline.core.config)
      end

      # Rebind Tab (^I = byte 9) to cycle agents forward when the buffer is
      # empty, otherwise fall through to normal completion.
      # Shift+Tab (ESC [ Z = bytes 27,91,90) cycles agents backward.
      repl = self
      Reline.line_editor.define_singleton_method(:cycle_or_complete) do |key|
        if current_line.empty?
          repl.send(:cycle_agent, :forward)
          @cache.delete(:prompt_list)
          @cache.delete(:wrapped_prompt_and_input_lines)
        else
          complete(key)
        end
      end

      Reline.line_editor.define_singleton_method(:reverse_cycle_agent) do |_key|
        if current_line.empty?
          repl.send(:cycle_agent, :backward)
          @cache.delete(:prompt_list)
          @cache.delete(:wrapped_prompt_and_input_lines)
        end
      end

      Reline.core.config.add_default_key_binding_by_keymap(:emacs, [9], :cycle_or_complete)
      Reline.core.config.add_default_key_binding_by_keymap(:emacs, [27, 91, 90], :reverse_cycle_agent)
    end

    # Reline completion callback.
    # - File paths: typing "./" launches fzf, injects selected path into the buffer.
    #   Backspacing back to "./" does NOT re-trigger.
    # - Slash commands: "/" at the beginning of a line.
    def complete_input(target, preposing = "", _postposing = "")
      prev = @last_completion_target
      @last_completion_target = target

      # ./ triggers fzf file picker (only on forward typing, not backspace)
      if target == "./"
        backspacing = prev&.start_with?("./") && prev.length > target.length
        unless backspacing
          path = fzf_pick_file
          if path
            cursor = Reline.point
            Reline.delete_text(cursor - target.bytesize, target.bytesize)
            Reline.point = cursor - target.bytesize
            Reline.insert_text(path)
          end
          # Invalidate Reline's render cache so it fully redraws prompt + buffer
          Reline.line_editor.send(:clear_rendered_screen_cache)
          Reline.redisplay
        end
        return []
      end

      # Slash commands at start of line
      if (preposing.nil? || preposing.strip.empty?) && target.start_with?("/")
        return Commands.names.select { |name| name.start_with?(target) }
      end

      []
    end

    def read_prompt
      puts BufferOutput::ModelLine.new(
        provider_name: @execution.provider_name,
        model_short: @execution.model_short,
        current_agent: @execution.current_agent,
      )
      input = Reline.readmultiline(current_prompt.colorize(ACCENT_BOLD) + " ", true) { |t| !t.rstrip.end_with?("\\") }
      return nil if input.nil?

      input.gsub(/\\\n/, "\n").strip
    end

    def current_prompt
      "%"
    end

    # ── Interactive selection ──
    # Model, provider, and agent selection are REPL concerns — Execution
    # only knows the configuration it's given.

    def cycle_agent(direction = :forward)
      agents = Execution::AGENTS
      shell_agents = Execution::SHELL_AGENTS
      step = direction == :backward ? -1 : 1
      idx = (agents.index(@execution.current_agent) + step) % agents.size
      new_agent = agents[idx]

      # Switch provider when entering/leaving shell-mode agents.
      if (shell_model = shell_agents[new_agent])
        activate_shell_agent!(shell_model)
      else
        restore_llm_provider!
      end

      @execution.current_agent = new_agent
      reset_agent!
      @execution.resolve_provider_info

      # Rewrite the model/status line sitting one line above the prompt.
      # Save cursor, move up, clear line, print, restore cursor.
      line = BufferOutput::ModelLine.new(
        provider_name: @execution.provider_name,
        model_short: @execution.model_short,
        current_agent: @execution.current_agent,
      ).to_s
      $stdout.print "\e[s\e[A\r\e[2K#{line}\e[u"
      $stdout.flush
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
        puts "Failed to fetch models: #{e.message}".colorize(ERROR_FG)
        @models_cache = []
      end

      @models_cache
    end

    # Save the current LLM provider symbol when entering a shell-mode agent.
    # The Execution builds a shell agent with Brute::Providers::Shell internally.
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
      # Token count is tracked by CLIEventHandler metadata during calls.
      # For now, return nil since compaction is not yet implemented.
      nil
    end

    # ── Commands ──

    # Dispatch a slash command. Returns :exit to break the REPL loop, or nil.
    def handle_command(input)
      entry = Commands.find(input)
      unless entry
        puts "Unknown command: #{input.split(/\s+/).first}".colorize(ERROR_FG)
        puts "Type /help for available commands.".colorize(DIM)
        return nil
      end

      send(entry.method_name)
    end

    def cmd_help
      puts separator
      puts "Available commands:".colorize(ACCENT_BOLD)
      puts
      Commands::REGISTRY.each do |entry|
        puts "  #{entry.name.ljust(12).colorize(ACCENT)}  #{entry.description.colorize(DIM)}"
      end
      puts separator
      nil
    end

    def cmd_exit
      :exit
    end

    def cmd_compact
      tokens = compact_conversation
      if tokens
        puts "Compacting conversation...".colorize(DIM)
        puts "Current token count: #{tokens}".colorize(DIM)
        puts "Manual compaction not yet implemented.".colorize(DIM)
      else
        puts "No active conversation to compact.".colorize(DIM)
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

    # Process action tuples returned by the menu system.
    def handle_menu_action(action, *args)
      case action
      when :set_model
        model_id = args.first
        select_model(model_id)
        puts separator
        puts "Model changed to: #{model_id.colorize(ACCENT)}"
        puts separator
      when :set_provider
        provider_name = args.first
        select_provider(provider_name)
        puts separator
        puts "Provider changed to: #{provider_name.colorize(ACCENT)}"
        puts "Select a model:".colorize(DIM)
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

        # Dynamic: models from the current provider
        menu(:models, "Select Model") do |m|
          models = repl.send(:fetch_models)
          current = execution.model_name

          models.each do |id|
            label = id == current ? "#{id} (current)" : id
            m.choice label, [:set_model, id]
          end

          m.choice "Back", :main
        end

        # Dynamic: only providers with configured API keys
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

    # ── UI ──

    def print_banner
      puts separator
      puts BruteCLI::MONIKER.chomp.colorize(DIM)
      puts separator
      puts "Version #{Brute::VERSION}".colorize(DIM)
      sid = @execution.session_id
      if sid
        session = @execution.instance_variable_get(:@session)
        session_path = session&.path || File.join(Execution::SESSIONS_DIR, sid, "session.jsonl")
        session_dir = File.dirname(session_path)
        puts separator
        puts "session_id:  ".colorize(DIM) + sid.colorize(ACCENT)
        puts "session_log: ".colorize(DIM) + session_dir.colorize(ACCENT)
      end
      check_dependencies
      puts separator
      puts "Type /help for available commands.".colorize(DIM)
      puts separator
    end

    def check_dependencies
      missing = []
      missing << ["bat",  "https://github.com/sharkdp/bat#installation", "diff syntax highlighting"]  unless BruteCLI::Bat.available?
      missing << ["fzf",  "https://github.com/junegunn/fzf#installation", "interactive selection"]    unless fzf_on_path?
      return if missing.empty?

      puts separator
      missing.each do |name, url, purpose|
        $stderr.puts " #{name} not found — recommended for #{purpose}.\n Install: #{url} ".colorize(background: :red, color: :white)
      end
    end

    def separator
      BufferOutput::Separator.new(width: @execution.detect_width)
    end

    def fzf_on_path?
      ENV["PATH"].to_s.split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, "fzf")) }
    end

    # Launch fzf inline and return the selected path as ./relative, or nil.
    def fzf_pick_file
      return nil unless fzf_on_path?

      selected = `git ls-files --cached --others --exclude-standard 2>/dev/null | fzf --prompt='Select File › ' --height=~20 --reverse --no-info`
      return nil unless $?.success?

      selected = selected.strip
      return nil if selected.empty?

      selected.start_with?("/", "./", "../") ? selected : "./#{selected}"
    rescue Errno::ENOENT
      nil
    end
  end
end
