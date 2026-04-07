# frozen_string_literal: true

module BruteCLI
  module ToolOutput
    class Undo < Base
      ICON = Emoji::REWIND

      private

      def summary
        path = arg(:path)
        path ? path.to_s.colorize(DIM) : ""
      end
    end
  end
end
