# frozen_string_literal: true

module BruteCLI
  module ToolOutput
    class TodoRead < Base
      ICON = Emoji::CLIPBOARD

      private

      def body_lines
        todos = result_val(:todos)
        todo_lines(todos)
      end
    end
  end
end
