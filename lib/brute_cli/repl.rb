# frozen_string_literal: true

require 'logger'
require 'io/console'
require 'reline'
require 'tty-spinner'
require 'brute_cli/styles'

module BruteCLI
  class REPL
    def initialize(options = {})
      @options = options
      @agent = nil
      @session = nil
      @width = detect_width
      @content_buf = +''
      @spinner = nil
    end

    def run_once(prompt)
      ensure_agent!
      execute(prompt)
    end

    def run_interactive
      print_banner
      resolve_provider_info
      setup_reline

      loop do
        result = read_prompt
        break if result.nil?
        next if result.empty?
        break if %w[exit quit].include?(result)

        ensure_agent!
        execute(result)
        $stdout.puts
      end
    rescue Interrupt
      $stdout.puts
    end

    private

    # ── Reline ──

    def setup_reline
      subtitle = build_subtitle

      Reline.prompt_proc = proc { |lines|
        lines.map.with_index do |_, i|
          i == 0 ? Styles::PROMPT.render('>') + ' ' : Styles::DIM_TEXT.render('.') + ' '
        end
      }

      Reline.add_dialog_proc(:brute_status, lambda {
        Reline::DialogRenderInfo.new(
          pos: Reline::CursorPos.new(0, cursor_pos.y > 0 ? 3 : 1),
          contents: [subtitle],
          width: screen_width
        )
      }, nil)
    end

    def read_prompt
      input = Reline.readmultiline(Styles::PROMPT.render('>') + ' ', true) { |t| !t.rstrip.end_with?('\\') }
      return nil if input.nil?

      input.gsub(/\\\n/, "\n").strip
    end

    # ── Provider ──

    def resolve_provider_info
      provider = begin
        Brute.provider
      rescue StandardError
        nil
      end
      @provider_name = provider&.name&.to_s
      @model_name = provider&.default_model&.to_s
    end

    def model_short
      @model_name&.sub(/^claude-/, '')&.sub(/-\d{8}$/, '') || @model_name
    end

    def build_subtitle
      parts = []
      parts << stat_span(@provider_name, model_short) if @provider_name && model_short
      parts << stat_span('agent', 'brute')
      '  ' + parts.join(Styles::DIM_TEXT.render(' · '))
    end

    def stat_span(label, value)
      Styles::DIM_TEXT.render("#{label} ") + Styles::STAT_VALUE.render(value)
    end

    # ── Agent ──

    def ensure_agent!
      return if @agent

      @session = Brute::Session.new(id: @options[:session_id])
      @agent = Brute.agent(
        cwd: @options[:cwd] || Dir.pwd,
        session: @session,
        logger: Logger.new(File::NULL),
        on_content: method(:on_content),
        on_reasoning: method(:on_reasoning),
        on_tool_call: method(:on_tool_call),
        on_tool_result: method(:on_tool_result)
      )
      @session.restore(@agent.context) if @options[:session_id]
    end

    # ── Execute ──

    def execute(prompt)
      @content_buf = +''

      print_model_line
      start_spinner('Thinking...')

      begin
        @agent.run(prompt)
      rescue Interrupt
        stop_spinner
        flush_content
        styled_puts Styles::DIM_TEXT.render('  Aborted.')
        print_stats_bar
        return
      rescue StandardError => e
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
      parts << stat_span('agent', 'brute')
      styled_puts '  ' + parts.join(Styles::DIM_TEXT.render(' · '))
    end

    # ── Spinner ──

    RAINBOW = [
      "\e[38;2;255;56;96m",  "\e[38;2;255;165;0m",
      "\e[38;2;255;220;0m",  "\e[38;2;0;219;68m",
      "\e[38;2;0;186;255m",  "\e[38;2;107;80;255m",
      "\e[38;2;255;96;255m"
    ].freeze
    RESET = "\e[0m"

    def nyan_frames
      bar = '━' * 12
      bar.length.times.map do |offset|
        bar.chars.map.with_index { |c, i| RAINBOW[(i + offset) % RAINBOW.length] + c }.join + RESET
      end
    end

    def start_spinner(label)
      stop_spinner
      @spinner = TTY::Spinner.new(
        "  :spinner #{label}",
        frames: nyan_frames,
        interval: 8,
        output: $stdout
      )
      @spinner.auto_spin
    end

    def stop_spinner
      return unless @spinner

      @spinner.stop('') if @spinner.spinning?
      @spinner = nil
    end

    # ── Callbacks ──

    def on_content(text)
      stop_spinner
      @content_buf << text
    end

    def on_reasoning(_text); end

    INLINE_TOOLS = %w[read fs_search todo_read todo_write fetch].freeze
    TOOL_ICONS = {
      'read' => Emoji::EYES, 'patch' => Emoji::HAMMER, 'write' => Emoji::WRITING,
      'shell' => Emoji::COMPUTER, 'fs_search' => Emoji::MAG, 'fetch' => Emoji::GLOBE,
      'todo_read' => Emoji::CLIPBOARD, 'todo_write' => Emoji::CLIPBOARD,
      'remove' => Emoji::WASTEBASKET, 'undo' => Emoji::REWIND, 'delegate' => Emoji::ROBOT
    }.freeze

    def on_tool_call(name, args)
      stop_spinner
      flush_content
      @pending_tool = { name: name, args: args }
    end

    def on_tool_result(name, result)
      stop_spinner
      tool = @pending_tool || { name: name, args: {} }

      if INLINE_TOOLS.include?(tool[:name])
        print_inline_tool(tool, result)
      else
        print_block_tool(tool, result)
      end

      @pending_tool = nil
      start_spinner('Thinking...')
    end

    # ── Output ──

    def flush_content
      return if @content_buf.strip.empty?

      rendered = glamour_render(@content_buf)
      $stdout.puts
      $stdout.puts rendered
      $stdout.flush
      @content_buf = +''
    end

    def glamour_render(text)
      width = [@width - 4, 40].max
      Glamour.render(text.strip, style: 'auto', width: width).rstrip
    rescue StandardError => _e
      text
    end

    def print_inline_tool(tool, result)
      icon = TOOL_ICONS[tool[:name].to_s] || Emoji::GEAR
      name = tool[:name].to_s
      summary = tool_summary(tool) || ''

      if error_result?(result)
        styled_puts "  #{icon} #{Styles::TOOL_BADGE.render(name)} #{summary} #{Styles::TOOL_FAIL.render('FAILED')}"
      else
        styled_puts "  #{icon} #{Styles::TOOL_BADGE.render(name)} #{summary}"
      end
    end

    def print_block_tool(tool, result)
      icon = TOOL_ICONS[tool[:name].to_s] || Emoji::GEAR
      name = tool[:name].to_s
      title = "#{icon} #{Styles::TOOL_BADGE.render(name)}"

      body_lines = []

      summary = tool_summary(tool) || ''
      body_lines << summary unless summary.empty?

      # Diff
      diff = result.is_a?(Hash) && (result[:diff] || result['diff'])
      body_lines.concat(format_diff_lines(diff)) if diff && !diff.strip.empty?

      # Shell output
      stdout = result.is_a?(Hash) && (result[:stdout] || result['stdout'])
      if stdout && !stdout.strip.empty?
        lines = stdout.strip.lines.map(&:chomp)
        lines = lines.first(15) + [Styles::DIM_TEXT.render('... (truncated)')] if lines.size > 15
        body_lines.concat(lines.map { |l| Styles::DIM_TEXT.render(l) })
      end

      # Status
      if error_result?(result)
        msg = error_message(result)
        msg = msg[0..70] + '...' if msg.length > 70
        body_lines << "#{Styles::TOOL_FAIL.render('FAILED')} #{Styles::DIM_TEXT.render(msg)}"
      else
        body_lines << Styles::TOOL_OK.render('OK')
      end

      styled_puts render_titled_frame(title, body_lines)
    end

    def error_result?(result)
      return false unless result.is_a?(Hash)

      result[:error] || result['error']
    end

    def error_message(result)
      return '' unless result.is_a?(Hash)

      (result[:message] || result['message'] || result[:error] || result['error']).to_s
    end

    def tool_summary(tool)
      args = tool[:args]
      return '' unless args.is_a?(Hash) && !args.empty?

      # Show the most relevant arg (file_path, command, etc.)
      path = args['file_path'] || args[:file_path]
      cmd = args['command'] || args[:command]
      pattern = args['pattern'] || args[:pattern]

      if path
        Styles::DIM_TEXT.render(path.to_s)
      elsif cmd
        Styles::DIM_TEXT.render(cmd.to_s[0..60])
      elsif pattern
        Styles::DIM_TEXT.render("\"#{pattern}\"")
      else
        ''
      end
    end

    def format_diff_lines(diff_text)
      diff_text.lines.map do |line|
        l = line.chomp
        case l[0]
        when '+' then Styles::DIFF_ADDED.render(l)
        when '-' then Styles::DIFF_REMOVED.render(l)
        when '@' then Styles::DIFF_HUNK.render(l)
        else          Styles::DIFF_CONTEXT.render(l)
        end
      end
    end

    def render_titled_frame(title, body_lines)
      m = Styles::SEPARATOR
      title_w = visible_width(title)
      body_w = body_lines.map { |l| visible_width(l) }.max || 0
      inner_w = [title_w, body_w].max + 2

      top = m.render('╭─ ') + title + ' ' + m.render('─' * [inner_w - title_w - 1, 0].max + '╮')
      bot = m.render('╰' + '─' * (inner_w + 2) + '╯')
      mid = body_lines.map do |l|
        pad = inner_w - visible_width(l)
        m.render('│') + ' ' + l + ' ' * [pad, 0].max + ' ' + m.render('│')
      end

      ([top] + mid + [bot]).join("\n")
    end

    def visible_width(str)
      str.gsub(/\e\[[0-9;]*m/, '').gsub(/\p{Emoji_Presentation}|\p{Emoji}\uFE0F?/, 'XX').length
    end

    # ── Stats ──

    def print_stats_bar
      metadata = @agent&.env&.dig(:metadata) || {}
      tokens = metadata[:tokens] || {}
      timing = metadata[:timing] || {}
      tool_calls = metadata[:tool_calls] || 0
      parts = []
      parts << format_stat('tokens', format_tokens(tokens))
      parts << format_stat('time', format_time(timing[:total_elapsed] || 0))
      parts << format_stat('tools', tool_calls.to_s) if tool_calls > 0
      $stdout.puts
      styled_puts separator
      styled_puts '  ' + parts.join(Styles::DIM_TEXT.render('  |  '))
      styled_puts separator
    end

    def format_stat(l, v)
      Styles::DIM_TEXT.render("#{l} ") + Styles::STAT_VALUE.render(v)
    end

    def format_tokens(t)
      total = t[:total] || 0
      return '0' if total == 0

      "#{total} (#{t[:total_input] || 0}in/#{t[:total_output] || 0}out)"
    end

    def format_time(s)
      s < 60 ? "#{s.round(1)}s" : "#{(s / 60).floor}m#{(s % 60).round(1)}s"
    end

    # ── Error ──

    def print_error(err)
      styled_puts "\n#{Styles::ERROR_BADGE.render('ERROR')} #{Styles::ERROR_REASON.render(err.message)}"
      styled_puts Styles::DIM_TEXT.render("  #{err.backtrace.first}") if ENV['BRUTE_DEBUG'] && err.backtrace&.first
    end

    # ── UI ──

    def print_banner
      styled_puts separator
      styled_puts Styles::DIM_TEXT.render("  brute #{Brute::VERSION} — interactive mode")
      styled_puts separator
      $stdout.puts
    end

    def styled_puts(text)
      $stdout.puts text
      $stdout.flush
    end

    def separator
      Styles::SEPARATOR.render('─' * [@width, 40].max)
    end

    def detect_width
      _rows, cols = IO.console&.winsize
      cols || 80
    rescue StandardError
      80
    end
  end
end
