# frozen_string_literal: true

require "tty-markdown"

module BruteCLI
  # Streaming markdown renderer powered by TTY::Markdown.
  #
  # Tokens arrive one-at-a-time from the LLM via SSE. The StreamFormatter
  # accumulates them into a buffer, printing raw characters for
  # immediate feedback. On each newline, new content is rendered
  # through TTY::Markdown.parse and only the uncommitted lines are
  # printed — previously rendered lines are left on screen untouched.
  #
  # This forward-only approach avoids cursor-repositioning bugs that
  # occur when terminal scrolling invalidates saved positions (both
  # DEC save/restore and cursor-up are affected).
  #
  #   fmt = BruteCLI::StreamFormatter.new(width: 80)
  #   streamer << "# He"          # prints raw "# He"
  #   streamer << "llo World\n"   # replaces raw chars with styled "Hello World"
  #   streamer.flush              # finalize any partial line
  #   streamer.reset              # ready for next turn
  #
  class StreamFormatter
    CLEAR_TO_EOL = "\e[K"

    def initialize(output: nil, width: nil)
      @output = output
      @width  = width || TTY::Screen.width
      reset
    end

    # Accept a chunk of streamed text. May contain zero, one, or many
    # newlines — each is handled correctly.
    def <<(text)
      text.each_char { |ch| consume(ch) }
    end

    # Finalize any partial (unterminated) line still in the buffer.
    # Called when the response ends or a tool call interrupts.
    #
    # After flushing, all state is cleared so the next block of
    # content (after tool frames, etc.) starts fresh.
    def flush
      return if @buffer.empty? && @line_buf.empty?
      @buffer << @line_buf unless @line_buf.empty?
      render_new_lines
      out.puts
      @buffer          = +""
      @line_buf        = +""
      @committed_lines = 0
    end

    # Reset all state for the next agent turn.
    def reset
      @buffer          = +""
      @line_buf        = +""
      @committed_lines = 0
    end

    private

    # Process a single character.
    def consume(ch)
      @line_buf << ch
      if ch == "\n"
        finish_line
      else
        out.print ch
      end
    end

    # A complete line arrived — append to the buffer and render any
    # new lines that TTY::Markdown produced.
    def finish_line
      @buffer << @line_buf
      @line_buf = +""
      render_new_lines
    end

    # Render the full buffer through TTY::Markdown for proper context
    # (code fences, lists, etc.), then print only the lines that
    # haven't been committed to screen yet. The raw characters on the
    # current line are cleared first with \r + clear-to-EOL.
    def render_new_lines
      rendered  = render_markdown(@buffer)
      lines     = rendered.lines
      new_lines = lines[@committed_lines..] || []

      # Clear the raw chars on the current line, then print new content.
      out.print "\r"
      out.print CLEAR_TO_EOL
      new_lines.each { |line| out.print line }

      @committed_lines = lines.length
    end

    def render_markdown(text)
      TTY::Markdown.parse(text, width: @width, color: :always)
    rescue => _e
      # If TTY::Markdown chokes on partial markdown, return raw text
      text
    end

    # Resolve the output stream. When no explicit output was provided,
    # use $stdout dynamically so that test helpers like capture_stdout
    # (which swap $stdout) work transparently.
    def out
      @output || $stdout
    end
  end
end
