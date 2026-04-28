# frozen_string_literal: true

require "tty-markdown"

module BruteCLI
  # Renders a growing text buffer through TTY::Markdown, tracking which
  # lines have already been printed so only new output is emitted.
  #
  # Extracted from StreamFormatter so it can be enabled/disabled
  # independently of the core streaming logic.
  #
  #   renderer = MarkdownRenderer.new(width: 80)
  #   renderer.render("# Hello\n")    # prints styled heading
  #   renderer.render("# Hello\nWorld\n")  # prints only "World" line
  #   renderer.reset
  #
  class MarkdownRenderer
    CLEAR_TO_EOL = "\e[K"

    def initialize(output: nil, width: nil)
      @output = output
      @width  = width || TTY::Screen.width
      @committed_lines = 0
    end

    # Render the full buffer, print only lines beyond what's already
    # been committed to screen.
    def render(buffer)
      rendered  = parse_markdown(buffer)
      lines     = rendered.lines
      new_lines = lines[@committed_lines..] || []

      out.print "\r"
      out.print CLEAR_TO_EOL
      new_lines.each { |line| out.print line }

      @committed_lines = lines.length
    end

    def reset
      @committed_lines = 0
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
