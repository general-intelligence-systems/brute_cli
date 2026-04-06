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
      @tool_count = 0
      @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

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

    def on_tool_call(name, args)
      stop_spinner
      flush_content
      @tool_count += 1
      @pending_tool = { name: name, args: args }
    end

    def on_tool_result(name, result)
      stop_spinner
      print_tool_box(@pending_tool || { name: name, args: {} }, result)
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

    def print_tool_box(tool, result)
      badge = Styles::TOOL_BADGE.render(tool[:name])
      args = tool[:args]
      header = if args.is_a?(Hash) && !args.empty?
                 arg_parts = args.map do |k, v|
                   val = v.to_s
                   val = val[0..50] + '...' if val.length > 50
                   "#{Styles::TOOL_ARG_KEY.render(k.to_s)}#{Styles::DIM_TEXT.render('=')}#{Styles::TOOL_ARG_VAL.render(val)}"
                 end
                 "#{badge} #{arg_parts.join(' ')}"
               else
                 badge
               end

      status = if result.is_a?(Hash) && result[:error]
                 detail = result[:error].to_s
                 detail = detail[0..70] + '...' if detail.length > 70
                 "#{Styles::TOOL_FAIL.render('FAILED')} #{Styles::DIM_TEXT.render(detail)}"
               else
                 Styles::TOOL_OK.render('OK')
               end

      styled_puts Styles::TOOL_FRAME.render("#{header}\n#{status}")
    end

    # ── Stats ──

    def print_stats_bar
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_time
      tokens = @agent&.env&.dig(:metadata, :tokens) || {}
      parts = []
      parts << format_stat('tokens', format_tokens(tokens))
      parts << format_stat('time', format_time(elapsed))
      parts << format_stat('tools', @tool_count.to_s) if @tool_count > 0
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
