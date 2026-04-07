# frozen_string_literal: true

require "json"
require "brute_cli/styles"
require "brute_cli/emoji"

module BruteCLI
  module BufferOutput
    # Renderable error badge with pretty-printed message.
    #
    #   puts BufferOutput::Error.new(err)
    #   # => "✖ ERROR"
    #   # => "\"Something went wrong\""
    #
    class Error
      def initialize(err)
        @err = err
      end

      def to_s
        header = "#{Emoji::CROSS} #{"ERROR".colorize(ERROR_BG)}"
        parsed = JSON.parse(@err.message) rescue @err.message
        "#{header}\n#{parsed.pretty_inspect.chomp}"
      end
    end
  end
end
