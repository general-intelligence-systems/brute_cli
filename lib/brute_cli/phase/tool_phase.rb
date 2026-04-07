# frozen_string_literal: true

module BruteCLI
  module Phase
    # Holds a batch of ToolCall objects for a single LLM turn.
    # The orchestrator fires on_tool_call_start with the full batch,
    # then on_tool_result per-tool as each completes.
    class ToolPhase
      attr_reader :tool_calls

      def initialize(calls)
        @tool_calls = calls.map do |c|
          ToolCall.new(name: c[:name], arguments: c[:arguments])
        end
      end

      # Resolve the first unresolved call matching +name+.
      # Returns the ToolCall, or nil if no match.
      def resolve(name, result)
        call = @tool_calls.find { |c| c.name == name && c.pending? }
        return unless call
        call.result = result
        call
      end

      def finished? = @tool_calls.all?(&:resolved?)
    end
  end
end
