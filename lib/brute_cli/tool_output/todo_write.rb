# frozen_string_literal: true

module BruteCLI
  module ToolOutput
    class TodoWrite < Base
      ICON = Emoji::CLIPBOARD

      private

      def body_lines
        todos = arg(:todos)
        todo_lines(todos)
      end
    end
  end
end
