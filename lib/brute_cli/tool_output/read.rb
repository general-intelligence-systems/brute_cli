# frozen_string_literal: true

module BruteCLI
  module ToolOutput
    class Read < Base
      ICON = Emoji::EYES

      private

      def summary
        path = arg(:file_path)
        path ? path.to_s.colorize(DIM) : ""
      end
    end
  end
end
