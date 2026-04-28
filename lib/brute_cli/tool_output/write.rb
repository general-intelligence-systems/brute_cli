# frozen_string_literal: true

module BruteCLI
  module ToolOutput
    class Write < Base
      ICON = Emoji::WRITING

      private

      def summary
        path = arg(:file_path)
        path ? path.to_s.colorize(DIM) : ""
      end
    end
  end
end
