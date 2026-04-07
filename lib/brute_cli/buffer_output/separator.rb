# frozen_string_literal: true

require "brute_cli/styles"

module BruteCLI
  module BufferOutput
    # Renderable horizontal rule for terminal output.
    #
    #   puts BufferOutput::Separator.new(width: 80)
    #   puts BufferOutput::Separator.new(width: 80, thick: true)
    #
    class Separator
      def initialize(width:, thick: false)
        @width = width
        @thick = thick
      end

      def to_s
        char = @thick ? "\u2550" : "\u2500"
        (char * [@width, 40].max).colorize(DIM)
      end
    end
  end
end
