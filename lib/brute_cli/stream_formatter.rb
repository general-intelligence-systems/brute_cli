# frozen_string_literal: true

require "tty-markdown"

module BruteCLI
  # Streaming markdown renderer powered by TTY::Markdown.
  #
  # Tokens arrive one-at-a-time from the LLM via SSE. The StreamFormatter
  # accumulates them into a buffer, printing raw characters for
  # immediate feedback. On each newline, the entire buffer is
  # re-rendered through TTY::Markdown.parse and the previous output
  # is overwritten via ANSI cursor save/restore.
  #
  # Uses DEC save/restore cursor (\e7 / \e8) — the terminal
  # tracks its own position, so we don't need fragile manual
  # row/column accounting.
  #
  #   fmt = BruteCLI::StreamFormatter.new(width: 80)
  #   streamer << "# He"          # prints raw "# He"
  #   streamer << "llo World\n"   # re-renders as styled "Hello World"
  #   streamer.flush              # finalize any partial line
  #   streamer.reset              # ready for next turn
  #
  class StreamFormatter
    SAVE_CURSOR    = "\e7"
    RESTORE_CURSOR = "\e8"
    CLEAR_TO_END   = "\e[J"

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
      restore_and_render
      out.puts
      @buffer       = +""
      @line_buf     = +""
      @origin_saved = false
    end

    # Reset all state for the next agent turn.
    def reset
      @buffer       = +""
      @line_buf     = +""
      @origin_saved = false
    end

    private

    # Process a single character.
    def consume(ch)
      save_origin unless @origin_saved
      @line_buf << ch
      if ch == "\n"
        finish_line
      else
        out.print ch
      end
    end

    # Save the cursor position at the start of this output block.
    # Called once before the first character is printed, then not
    # again until after a flush or reset.
    def save_origin
      out.print SAVE_CURSOR
      @origin_saved = true
    end

    # A complete line arrived — append to the buffer and re-render.
    def finish_line
      @buffer << @line_buf
      @line_buf = +""
      restore_and_render
    end

    # Restore cursor to the saved origin, clear everything after it,
    # and print the fully rendered markdown.
    def restore_and_render
      rendered = render_markdown(@buffer)
      out.print RESTORE_CURSOR
      out.print CLEAR_TO_END
      out.print rendered
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
