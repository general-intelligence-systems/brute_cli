# frozen_string_literal: true

module BruteCLI
  # Handles Reline prompt setup and reading user input.
  #
  # Decoupled from Execution — receives the terminal for output,
  # display data via a simple Struct, and returns intent hashes
  # that the REPL interprets.
  #
  # Intents returned by #read_prompt:
  #
  #   nil                                        — EOF / Ctrl-D
  #   { type: :input,       text: "..." }        — user typed a prompt
  #   { type: :cycle_agent, direction: :forward } — Tab on empty line
  #   { type: :cycle_agent, direction: :backward} — Shift-Tab on empty line
  #
  # The caller must update the status and call #read_prompt again after
  # handling a :cycle_agent intent.
  #
  PromptStatus = Struct.new(:provider_name, :model_short, :current_agent, keyword_init: true)

  class UserInput
    def initialize(terminal)
      @terminal = terminal
      @last_completion_target = nil
      @pending_intent = nil

      setup_reline
    end

    # Read one prompt from the user.
    #
    # +status+ is a PromptStatus with the current display info.
    # Returns an intent hash (see class doc) or nil on EOF.
    def read_prompt(status)
      # If a Tab/Shift-Tab cycle was triggered during the last Reline
      # session, return that intent immediately so the REPL can update
      # the agent and re-render.
      if @pending_intent
        intent = @pending_intent
        @pending_intent = nil
        return intent
      end

      print_model_line(status)

      input = Reline.readmultiline(current_prompt.colorize(ACCENT_BOLD) + " ", true) do |t|
        !t.rstrip.end_with?("\\")
      end

      # A cycle intent was triggered during input — return it instead
      # of the (empty) text the user entered.
      if @pending_intent
        intent = @pending_intent
        @pending_intent = nil
        return intent
      end

      return nil if input.nil?

      { type: :input, text: input.gsub(/\\\n/, "\n").strip }
    end

    # Re-render the model/status line in-place (one line above prompt).
    # Called by the REPL after handling a :cycle_agent intent.
    def refresh_model_line(status)
      line = BufferOutput::ModelLine.new(
        provider_name: status.provider_name,
        model_short:   status.model_short,
        current_agent: status.current_agent,
      ).to_s
      @terminal.buffer.print "\e[s\e[A\r\e[2K#{line}\e[u"
      @terminal.buffer.flush
    end

    private

    def current_prompt
      "%"
    end

    def print_model_line(status)
      @terminal.buffer << BufferOutput::ModelLine.new(
        provider_name: status.provider_name,
        model_short:   status.model_short,
        current_agent: status.current_agent,
      )
    end

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
      user_input = self
      Reline.line_editor.define_singleton_method(:cycle_or_complete) do |key|
        if current_line.empty?
          user_input.send(:enqueue_cycle, :forward)
          @cache.delete(:prompt_list)
          @cache.delete(:wrapped_prompt_and_input_lines)
        else
          complete(key)
        end
      end

      Reline.line_editor.define_singleton_method(:reverse_cycle_agent) do |_key|
        if current_line.empty?
          user_input.send(:enqueue_cycle, :backward)
          @cache.delete(:prompt_list)
          @cache.delete(:wrapped_prompt_and_input_lines)
        end
      end

      Reline.core.config.add_default_key_binding_by_keymap(:emacs, [9], :cycle_or_complete)
      Reline.core.config.add_default_key_binding_by_keymap(:emacs, [27, 91, 90], :reverse_cycle_agent)
    end

    # Called from the Reline key-binding callbacks.
    def enqueue_cycle(direction)
      @pending_intent = { type: :cycle_agent, direction: direction }
    end

    # Reline completion callback.
    # - File paths: typing "./" launches fzf, injects selected path into the buffer.
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

    def fzf_pick_file
      return nil unless fzf_on_path?

      selected = `git ls-files --cached --others --exclude-standard 2>/dev/null | fzf --prompt='Select File > ' --height=~20 --reverse --no-info`
      return nil unless $?.success?

      selected = selected.strip
      return nil if selected.empty?

      selected.start_with?("/", "./", "../") ? selected : "./#{selected}"
    rescue Errno::ENOENT
      nil
    end

    def fzf_on_path?
      ENV["PATH"].to_s.split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, "fzf")) }
    end
  end
end
