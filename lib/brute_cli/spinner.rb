# frozen_string_literal: true

module BruteCLI
  module Spinner
    # Abstract base class for CLI spinners.
    #
    # Subclasses must implement:
    #   #start     – begin the spinner animation
    #   #stop      – halt the spinner animation
    #   #spinning? – whether the spinner is currently animating
    #
    class Base
      def start
        raise NotImplementedError, "#{self.class.name} must implement #start"
      end

      def stop
        raise NotImplementedError, "#{self.class.name} must implement #stop"
      end

      def spinning?
        raise NotImplementedError, "#{self.class.name} must implement #spinning?"
      end
    end
  end
end

require "brute_cli/spinner/nyan"
require "brute_cli/spinner/dots"
require "brute_cli/spinner/puff_puff_pass"
