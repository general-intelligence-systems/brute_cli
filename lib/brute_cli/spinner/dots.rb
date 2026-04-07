# frozen_string_literal: true

require "tty-spinner"

module BruteCLI
  module Spinner
    class Dots < Base
      def start
        stop if spinning?
        @tty = TTY::Spinner.new(output: $stdout, clear: true)
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
