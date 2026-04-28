# frozen_string_literal: true

require "tty-markdown"

module BruteCLI
  # Renders a growing text buffer through TTY::Markdown, tracking which
  # lines have already been printed so only new output is emitted.
  #
  # Designed for incremental/streaming use: call #render repeatedly
  # with the full accumulated buffer.  Only lines beyond the previous
  # high-water mark are printed.  The last line is held back when it
  # does not end with a newline because it may still be incomplete —
  # it will be emitted on the next call once more text arrives, or
  # when #flush forces the final render.
  #
  #   renderer = MarkdownRenderer.new(width: 80)
  #   renderer.render("# Hello\n")        # prints styled heading
  #   renderer.render("# Hello\nWorld\n") # prints only "World" line
  #   renderer.flush                      # no-op (nothing pending)
  #   renderer.reset
  #
  class MarkdownRenderer
    CLEAR_TO_EOL = "\e[K"

    def initialize(output: nil, width: nil)
      @output = output
      @width  = width || TTY::Screen.width
      @committed_lines = 0
      @buffer = +""
    end

    # Render the full buffer, print only lines beyond what's already
    # been committed to screen.  Holds back the last line if it does
    # not end with a newline (it may be a partial/in-progress line).
    def render(buffer)
      @buffer = buffer
      rendered  = parse_markdown(buffer)
      lines     = rendered.lines

      # If the source buffer doesn't end with a newline, the last
      # rendered line is potentially incomplete — hold it back.
      printable = buffer.end_with?("\n") ? lines : lines[0...-1]
      new_lines = (printable || [])[@committed_lines..] || []

      return if new_lines.empty?

      out.print "\r"
      out.print CLEAR_TO_EOL
      new_lines.each { |line| out.print line }

      @committed_lines += new_lines.length
    end

    # Force-render any held-back trailing content (e.g. the last
    # incomplete line).  Called at the end of an agent turn.
    def flush
      return if @buffer.empty?

      rendered  = parse_markdown(@buffer)
      lines     = rendered.lines
      new_lines = (lines || [])[@committed_lines..] || []

      return if new_lines.empty?

      out.print "\r"
      out.print CLEAR_TO_EOL
      new_lines.each { |line| out.print line }

      @committed_lines = lines.length
    end

    def reset
      @committed_lines = 0
      @buffer = +""
    end

    private

    def parse_markdown(text)
      TTY::Markdown.parse(text, width: @width, color: :always)
    rescue => _e
      text
    end

    def out
      @output || $stdout
    end
  end
end
