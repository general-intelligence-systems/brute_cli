# frozen_string_literal: true

module BruteCLI
  # Bridges Brute 2.0's event-sink architecture to the CLI's rendering
  # callbacks.  Wraps an Execution instance and dispatches typed events
  # to the appropriate rendering methods.
  #
  # Event types emitted by brute 2.0 middleware:
  #
  #   :content          – streamed text chunk (String)
  #   :reasoning        – reasoning/thinking chunk (String)
  #   :tool_call_start  – batch of tool calls starting (Array<Hash>)
  #   :tool_result      – single tool completed (Hash with :name, :content)
  #   :log              – debug/trace log line (String)
  #   :error            – error info (Hash or Exception)
  #   :assistant_complete – turn finished (nil)
  #
  class CLIEventHandler < Brute::Events::Handler
    attr_reader :metadata

    def initialize(inner, execution:)
      super(inner)
      @execution = execution
      @metadata = { tokens: {}, timing: {}, tool_calls: 0 }
    end

    def <<(event)
      h = event.is_a?(Hash) ? event : event.to_h
      type = h[:type]
      data = h[:data]

      case type
      when :content
        @execution.send(:on_content, data)
      when :reasoning
        @execution.send(:on_reasoning, data)
      when :tool_call_start
        @metadata[:tool_calls] += data.size
        # Convert to the format Execution expects: array of hashes with
        # :name and :arguments keys (matching Phase::ToolCall interface)
        calls = data.map do |tc|
          { name: tc[:name], arguments: tc[:arguments] }
        end
        @execution.send(:on_tool_call_start, calls)
      when :tool_result
        @execution.send(:on_tool_result, data[:name], data[:content])
      when :log
        # silently ignore — tracing logs go to the logger
      when :error
        # errors are handled by the rescue in Execution#execute
      when :assistant_complete
        # no-op — stats are printed by Execution after the call returns
      end

      super
    end

    # Merge timing data from the agent env after a call completes.
    def merge_metadata!(env_metadata)
      @metadata[:timing] = env_metadata[:timing] || {}
      # Token data may come from the tracing middleware or response usage
      @metadata[:tokens] = env_metadata[:tokens] || @metadata[:tokens]
    end
  end
end
