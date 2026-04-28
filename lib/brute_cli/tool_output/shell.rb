# frozen_string_literal: true

module BruteCLI
  module ToolOutput
    class Shell < Base
      ICON = Emoji::COMPUTER

      private

      def summary
        cmd = arg(:command)
        cmd ? cmd.to_s[0..60].colorize(DIM) : ""
      end
    end
  end
end
