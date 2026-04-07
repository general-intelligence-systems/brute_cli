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

      def body_lines
        stdout = result_val(:stdout)
        return [] unless stdout && !stdout.to_s.strip.empty?

        lines = stdout.strip.lines.map(&:chomp)
        lines = lines.first(15) + ["... (truncated)"] if lines.size > 15
        lines.map { |l| l.colorize(DIM) }
      end
    end
  end
end
