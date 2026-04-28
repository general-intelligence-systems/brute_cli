# frozen_string_literal: true

module BruteCLI
  # Buffers streamed text and prints it directly to the terminal.
  #
  # Content arrives in chunks (single chars, partial lines, or full
  # paragraphs) via <<. Each chunk is appended to an internal buffer
  # and printed immediately. flush finalises any remaining content.
  #
  #   fmt = BruteCLI::StreamFormatter.new(width: 80)
  #   fmt << "Hello "
  #   fmt << "World\n"
  #   fmt.flush
  #   fmt.reset
  #
  class StreamFormatter
    def initialize(output: nil, width: nil)
      @output = output
      @width  = width || TTY::Screen.width
      reset
    end

    # Accept a chunk of streamed text and print it.
    def <<(text)
      @buffer << text
      out.print text
    end

    # Finalize any remaining content. Ensures output ends with a
    # newline so subsequent output starts on a fresh line.
    def flush
      return if @buffer.empty?
      out.puts unless @buffer.end_with?("\n")
      @buffer = +""
    end

    # Reset all state for the next agent turn.
    def reset
      @buffer = +""
    end

    private

    def out
      @output || $stdout
    end
  end
end
