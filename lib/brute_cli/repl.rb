# frozen_string_literal: true

require "logger"
require "io/console"
require "json"
require "pp"
require "reline"
require "tty-spinner"
require "brute_cli/styles"
require "brute_cli/question_screen"

module BruteCLI
  class REPL
    AGENTS = %w[build plan].freeze

    def initialize(options = {})
      @options = options
      @current_agent = AGENTS.first
      @agent = nil
      @session = nil
      @selected_model = nil    # user-chosen model override (nil = provider default)
      @models_cache = nil      # cached model list from provider API
      @width = TTY::Screen.width
      @content_buf = +""
      @streamer = StreamFormatter.new(width: @width)
      @spinner = nil
      @mu = Mutex.new
    end

    def run_once(prompt)
      ensure_agent!
      execute(prompt)
    end

    def run_interactive
      ensure_session!
      print_banner
      resolve_provider_info
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

        ensure_agent!
        execute(result)
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

      # Rebind Tab (^I = byte 9) to cycle agents when the buffer is empty,
      # otherwise fall through to normal completion. We define a custom method
      # on the singleton LineEditor instance and point the emacs keymap at it.
      repl = self
      Reline.line_editor.define_singleton_method(:cycle_or_complete) do |key|
        if current_line.empty?
          repl.send(:cycle_agent)
          # Reline caches prompt_list based on (whole_lines, mode_string).
          # Since neither changed, the cache returns the stale prompt.
          # Clear it so the next rerender re-evaluates prompt_proc.
          @cache.delete(:prompt_list)
          @cache.delete(:wrapped_prompt_and_input_lines)
        else
          complete(key)
        end
      end
      Reline.core.config.add_default_key_binding_by_keymap(:emacs, [9], :cycle_or_complete)
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
      print_model_line
      input = Reline.readmultiline(current_prompt.colorize(ACCENT_BOLD) + " ", true) { |t| !t.rstrip.end_with?("\\") }
      return nil if input.nil?

      input.gsub(/\\\n/, "\n").strip
    end

    # ── Provider ──

    def resolve_provider_info
      provider = Brute.provider rescue nil
      @provider_name = provider&.name&.to_s
      @model_name = @selected_model || provider&.default_model&.to_s
    end

    def model_short
      @model_name&.sub(/^claude-/, "")&.sub(/-\d{8}$/, "") || @model_name
    end

    def build_subtitle
      parts = []
      parts << stat_span(@provider_name, model_short) if @provider_name && model_short
      parts << stat_span("agent", @current_agent)
      parts.join(" · ".colorize(DIM))
    end

    def stat_span(label, value)
      "#{label} ".colorize(DIM) + value.to_s.colorize(ACCENT)
    end

    # ── Agent ──

    def ensure_session!
      return if @session
      @session = Brute::Session.new(id: @options[:session_id])
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
        on_content:     method(:on_content),
        on_reasoning:   method(:on_reasoning),
        on_tool_call:   method(:on_tool_call),
        on_tool_result: method(:on_tool_result),
        # on_question: disabled until bubbletea terminal integration is fixed
      )
      @session.restore(@agent.context) if @options[:session_id]
    end

    # Force the agent to be recreated on next ensure_agent! call.
    # Used after changing provider, model, or agent.
    def reset_agent!
      @agent = nil
      @models_cache = nil
    end

    def current_prompt
      "%"
    end

    def cycle_agent
      idx = (AGENTS.index(@current_agent) + 1) % AGENTS.size
      @current_agent = AGENTS[idx]
      reset_agent!
      # Rewrite the model/status line sitting one line above the prompt.
      # Save cursor, move up, clear line, print, restore cursor.
      parts = []
      parts << stat_span(@provider_name, model_short) if @provider_name && model_short
      parts << stat_span("agent", @current_agent)
      line = parts.join(" · ".colorize(DIM))
      $stdout.print "\e[s\e[A\r\e[2K#{line}\e[u"
      $stdout.flush
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
      if @agent
        puts "Compacting conversation...".colorize(DIM)
        # Trigger compaction by sending a hint through the pipeline
        # For now, just report the current token count
        metadata = @agent.env&.dig(:metadata) || {}
        tokens = metadata.dig(:tokens, :total) || 0
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
        @selected_model = model_id
        reset_agent!
        resolve_provider_info
        puts separator
        puts "Model changed to: #{model_id.colorize(ACCENT)}"
        puts separator
      when :set_provider
        provider_name = args.first
        new_provider = Brute.provider_for(provider_name)
        if new_provider
          Brute.provider = new_provider
          @selected_model = nil
          reset_agent!
          resolve_provider_info
          puts separator
          puts "Provider changed to: #{provider_name.colorize(ACCENT)}"
          puts "Model: #{@model_name.colorize(ACCENT)}"
          puts separator
        else
          puts "Failed to initialize provider: #{provider_name}".colorize(ERROR_FG)
        end
      end
    end

    # ── Menu Builder ──

    def build_main_menu
      repl = self

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
          current = repl.instance_variable_get(:@model_name)

          models.each do |id|
            label = id == current ? "#{id} (current)" : id
            m.choice label, [:set_model, id]
          end

          m.choice "Back", :main
        end

        # Dynamic: only providers with configured API keys
        menu(:providers, "Select Provider") do |m|
          configured = Brute.configured_providers
          current = repl.instance_variable_get(:@provider_name)

          configured.each do |name|
            label = name == current ? "#{name} (current)" : name
            m.choice label, [:set_provider, name]
          end

          m.choice "Back", :main
        end
      end
    end

    # Fetch available chat models from the current provider.
    # Results are cached for the session to avoid repeated API calls.
    def fetch_models
      return @models_cache if @models_cache

      provider = Brute.provider
      return [] unless provider

      begin
        all = provider.models.all
        @models_cache = all.select(&:chat?).map { |m| m.id.to_s }.sort
      rescue => e
        puts "Failed to fetch models: #{e.message}".colorize(ERROR_FG)
        # Fall back to just the default model
        @models_cache = [provider.default_model.to_s]
      end

      @models_cache
    end

    # ── Execute ──

    def execute(prompt)
      @content_buf = +""
      @streamer.reset

      start_spinner("Thinking...")

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

    def print_model_line
      parts = []
      parts << stat_span(@provider_name, model_short) if @provider_name && model_short
      parts << stat_span("agent", @current_agent)
      puts parts.join(" · ".colorize(DIM))
    end

    # ── Spinner ──

    RAINBOW = [
      "\e[38;2;255;56;96m", "\e[38;2;255;165;0m",
      "\e[38;2;255;220;0m", "\e[38;2;0;219;68m",
      "\e[38;2;0;186;255m", "\e[38;2;107;80;255m",
      "\e[38;2;255;96;255m",
    ].freeze
    RESET = "\e[0m"

    def nyan_frames
      bar = "━" * 12
      bar.length.times.map do |offset|
        bar.chars.map.with_index { |c, i| RAINBOW[(i + offset) % RAINBOW.length] + c }.join + RESET
      end
    end

    def start_spinner(label)
      stop_spinner
      puts separator
      @spinner = TTY::Spinner.new(
        ":spinner #{label}",
        frames: nyan_frames,
        interval: 8,
        output: $stdout,
        clear: true,
      )
      @spinner.auto_spin
    end

    def stop_spinner
      if @spinner
        if @spinner.spinning?
          @spinner.stop
        end
        @spinner = nil
      end
    end

    # ── Callbacks ──

    def on_content(text)
      @mu.synchronize do
        stop_spinner
        @content_buf << text
        @streamer << text
      end
    end

    def on_reasoning(_text); end

    TOOL_ICONS = {
      "read" => Emoji::EYES, "patch" => Emoji::HAMMER, "write" => Emoji::WRITING,
      "shell" => Emoji::COMPUTER, "fs_search" => Emoji::MAG, "fetch" => Emoji::GLOBE,
      "todo_read" => Emoji::CLIPBOARD, "todo_write" => Emoji::CLIPBOARD,
      "remove" => Emoji::WASTEBASKET, "undo" => Emoji::REWIND, "delegate" => Emoji::ROBOT,
      "question" => Emoji::DIAMOND,
    }.freeze

    TODO_STATUS = {
      "pending"     => Emoji::SQUARE,
      "in_progress" => Emoji::ARROWS,
      "completed"   => Emoji::CHECK,
      "cancelled"   => Emoji::CROSS,
    }.freeze

    def on_tool_call(name, args)
      @mu.synchronize do
        stop_spinner
        flush_content
        @pending_tool = { name: name, args: args }
      end
    end

    def on_tool_result(name, result)
      @mu.synchronize do
        stop_spinner
        tool = @pending_tool || { name: name, args: {} }

        puts separator
        print_tool_result(tool, result)

        @pending_tool = nil
        start_spinner("Thinking...")
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
      unless @content_buf.strip.empty?
        @streamer.flush
        @content_buf = +""
      end
    end

    def render_markdown(text)
      BruteCLI::Bat.markdown_mode(text.strip, width: @width)
    end

    def print_tool_result(tool, result)
      icon = TOOL_ICONS[tool[:name].to_s] || Emoji::GEAR
      name = tool[:name].to_s
      summary = tool_summary(tool) || ""

      puts "#{icon} #{name.colorize(ACCENT_BG)} #{summary}"

      # Diff
      diff = result.is_a?(Hash) && (result[:diff] || result["diff"])
      if diff && !diff.strip.empty?
        print BruteCLI::Bat.diff_mode(diff, width: @width)
      end

      # Shell output
      stdout = result.is_a?(Hash) && (result[:stdout] || result["stdout"])
      if stdout && !stdout.strip.empty?
        lines = stdout.strip.lines.map(&:chomp)
        lines = lines.first(15) + ["... (truncated)"] if lines.size > 15
        lines.each { |l| puts l.colorize(DIM) }
      end

      # Todos
      todos = extract_todos(tool, result)
      if todos && !todos.empty?
        format_todos(todos).each { |line| puts line }
      end

      # Error (only on failure)
      if error_result?(result)
        msg = error_message(result)
        msg = msg[0..70] + "..." if msg.length > 70
        puts "#{"FAILED".colorize(ERROR_BG)} #{msg.colorize(DIM)}"
      end
    end

    def extract_todos(tool, result)
      name = tool[:name].to_s
      if name == "todo_write"
        args = tool[:args]
        args = args.is_a?(Hash) ? (args[:todos] || args["todos"]) : nil
      elsif name == "todo_read"
        result.is_a?(Hash) ? (result[:todos] || result["todos"]) : nil
      end
    end

    def format_todos(todos)
      todos.map do |t|
        t = t.transform_keys(&:to_s) if t.is_a?(Hash)
        status = t["status"].to_s
        icon = TODO_STATUS[status] || Emoji::SQUARE
        content = t["content"] || t["id"] || "?"
        "  #{icon} #{content}"
      end
    end

    def error_result?(result)
      result.is_a?(Hash) && (result[:error] || result["error"])
    end

    def error_message(result)
      if result.is_a?(Hash)
        (
          result[:message]  ||
          result["message"] ||
          result[:error]    ||
          result["error"]
        ).to_s
      else
        ""
      end
    end

    def tool_summary(tool)
      args = tool[:args]
      return "" unless args.is_a?(Hash) && !args.empty?

      path    = args["file_path"] || args[:file_path]
      cmd     = args["command"]   || args[:command]
      pattern = args["pattern"]   || args[:pattern]

      if    path    then path.to_s.colorize(DIM)
      elsif cmd     then cmd.to_s[0..60].colorize(DIM)
      elsif pattern then "\"#{pattern}\"".colorize(DIM)
      else  ""
      end
    end

    # ── Stats ──

    def print_stats_bar
      metadata = @agent&.env&.dig(:metadata) || {}
      tokens = metadata[:tokens] || {}
      timing = metadata[:timing] || {}
      tool_calls = metadata[:tool_calls] || 0
      sep = " | ".colorize(DIM)
      parts = []
      parts << stat_span("tokens", (tokens[:total] || 0).to_s)
      parts << stat_span("in", (tokens[:total_input] || 0).to_s)
      parts << stat_span("out", (tokens[:total_output] || 0).to_s)
      parts << stat_span("time", format_time(timing[:total_elapsed] || 0))
      parts << stat_span("tools", tool_calls.to_s) if tool_calls > 0
      puts
      puts separator
      puts parts.join(sep)
      puts thick_separator
    end

    def format_time(s)
      s < 60 ? "#{s.round(1)}s" : "#{(s / 60).floor}m#{(s % 60).round(1)}s"
    end

    # ── Error ──

    def print_error(err)
      puts "#{Emoji::CROSS} #{"ERROR".colorize(ERROR_BG)}"
      parsed = JSON.parse(err.message) rescue err.message
      pp parsed
    end

    # ── UI ──

    def print_banner
      puts separator
      puts BruteCLI::LOGO.chomp.colorize(ACCENT)
      puts separator
      puts "Version #{Brute::VERSION}".colorize(DIM)
      if @session
        session_dir = File.join(Dir.home, ".brute", "sessions", @session.id)
        puts separator
        puts "session_id:  ".colorize(DIM) + @session.id.colorize(ACCENT)
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

    def separator
      ("─" * [@width, 40].max).colorize(ACCENT)
    end

    def thick_separator
      ("═" * [@width, 40].max).colorize(ACCENT)
    end

    def detect_width
      TTY::Screen.width
    end
  end
end
