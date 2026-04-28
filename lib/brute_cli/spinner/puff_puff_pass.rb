# frozen_string_literal: true

require "tty-spinner"

module BruteCLI
  module Spinner
    class PuffPuffPass < Base
      FRAMES = (1..4).map { |n| (Emoji::SMOKE + " ") * n }.freeze

      def start
        stop if spinning?
        @tty = TTY::Spinner.new(
          ":spinner",
          frames: FRAMES,
          interval: 200,
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
    end
  end
end
