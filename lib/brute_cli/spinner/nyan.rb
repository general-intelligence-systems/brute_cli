# frozen_string_literal: true

require "tty-spinner"

module BruteCLI
  module Spinner
    class Nyan < Base
      RAINBOW = [
        "\e[38;2;255;56;96m", "\e[38;2;255;165;0m",
        "\e[38;2;255;220;0m", "\e[38;2;0;219;68m",
        "\e[38;2;0;186;255m", "\e[38;2;107;80;255m",
        "\e[38;2;255;96;255m",
      ].freeze
      RESET = "\e[0m"

      def start
        stop if spinning?
        @tty = TTY::Spinner.new(
          ":spinner #{label}",
          frames: frames,
          interval: interval,
          output: @output,
          clear: true,
        )
        @tty.auto_spin
      end

      def stop
        @tty&.stop
        @tty = nil
      end

      def spinning?
        @tty&.spinning? || false
      end

      def label
        "Thinking..."
      end

      def frames
        bar = "\u2501" * 12
        bar.length.times.map do |offset|
          bar.chars.map.with_index { |c, i| RAINBOW[(i + offset) % RAINBOW.length] + c }.join + RESET
        end
      end

      def interval
        8
      end
    end
  end
end
