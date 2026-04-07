# frozen_string_literal: true

module BruteCLI
  module ToolOutput
    class FsSearch < Base
      ICON = Emoji::MAG

      private

      def summary
        pattern = arg(:pattern)
        pattern ? "\"#{pattern}\"".colorize(DIM) : ""
      end
    end
  end
end
