# frozen_string_literal: true

module BruteCLI
  module Phase
    # Pure data object representing a single tool invocation.
    # Holds name, arguments, and (once resolved) the result.
    class ToolCall
      attr_reader :name, :arguments
      attr_accessor :result

      def initialize(name:, arguments:)
        @name = name
        @arguments = arguments || {}
        @result = nil
      end

      def resolved? = !@result.nil?
      def pending?  = @result.nil?
    end
  end
end
