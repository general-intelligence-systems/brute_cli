# frozen_string_literal: true

module BruteCLI
  module ToolOutput
    class Delegate < Base
      ICON = Emoji::ROBOT

      private

      def summary
        task = arg(:task)
        task ? task.to_s[0..60].colorize(DIM) : ""
      end
    end
  end
end
