# frozen_string_literal: true

module BruteCLI
  # Buffers streamed text and renders it as styled Markdown via
  # TTY::Markdown.  Content arrives in small chunks (tokens) via <<.
  # Each chunk is appended to an internal buffer; whenever a newline
  # lands the accumulated buffer is passed through MarkdownRenderer
  # which only emits lines not yet printed to screen.
  #
  # Call #flush after the agent turn completes to render any remaining
  # content, then #reset before the next turn.
  #
  #   fmt = BruteCLI::StreamFormatter.new(width: 80)
  #   fmt << "# Hello "
  #   fmt << "World\n"   # triggers incremental markdown render
  #   fmt.flush
  #   fmt.reset
  #
  class StreamFormatter
    def initialize(output: nil, width: nil)
      @output   = output
      @width    = width || TTY::Screen.width
      @renderer = MarkdownRenderer.new(output: output, width: @width)
      reset
    end

    # Accept a chunk of streamed text.  Accumulate it and, when the
    # chunk contains a newline, re-render the full buffer through
    # TTY::Markdown (the renderer tracks already-printed lines).
    def <<(text)
      @buffer << text
      render_incremental if text.include?("\n")
    end

    # Finalize any remaining content at the end of an agent turn.
    # Forces a final markdown render pass and ensures output ends
    # with a newline.
    def flush
      return if @buffer.empty?

      render_incremental
      out.puts unless @buffer.end_with?("\n")
    end

    # Reset all state for the next agent turn.
    def reset
      @buffer = +""
      @renderer.reset
    end

    private

    def render_incremental
      @renderer.render(@buffer)
    end

    def out
      @output || $stdout
    end
  end
end
