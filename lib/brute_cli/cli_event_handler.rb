# frozen_string_literal: true

module BruteCLI
  # Bridges Brute 2.0's event-sink architecture to the CLI's terminal
  # rendering.  This IS the callback object — it reacts to events directly
  # by managing phases, the spinner, and terminal output.
  #
  # Requires three collaborators:
  #
  #   terminal:  BruteCLI::Terminal   — buffer / separator / width
  #   spinner:   BruteCLI::Spinner    — start / stop / spinning?
  #   streamer:  BruteCLI::StreamFormatter — streaming markdown output
  #
  class CLIEventHandler < Brute::Events::Handler
    SAVE_CURSOR    = "\e7"
    RESTORE_CURSOR = "\e8"
    CLEAR_TO_END   = "\e[J"

    attr_reader :metadata

    def initialize(inner, terminal:, spinner:, streamer:)
      super(inner)
      @terminal = terminal
      @spinner  = spinner
      @streamer = streamer
      @metadata = { tokens: {}, timing: {}, tool_calls: 0 }
      @current_phase = nil
      @last_output   = nil
    end

    def <<(event)
      h = event.is_a?(Hash) ? event : event.to_h
      type = h[:type]
      data = h[:data]

      case type
      when :content
        on_content(data)
      when :reasoning
        on_reasoning(data)
      when :tool_call_start
        @metadata[:tool_calls] += data.size
        calls = data.map do |tc|
          { name: tc[:name], arguments: tc[:arguments] }
        end
        on_tool_call_start(calls)
      when :tool_result
        on_tool_result(data[:name], data[:content])
      when :log, :error, :assistant_complete
        # log → tracing logger; error → rescue in Execution#execute;
        # assistant_complete → stats printed after call returns.
      end

      super
    end

    # Merge timing data from the agent env after a call completes.
    def merge_metadata!(env_metadata)
      @metadata[:timing] = env_metadata[:timing] || {}
      @metadata[:tokens] = env_metadata[:tokens] || @metadata[:tokens]
    end

    # ── Spinner ──

    def start_spinner
      stop_spinner

      unless @last_output == :separator
        @terminal.buffer << @terminal.separator
        @last_output = :separator
      end

      @spinner.start
    end

    def stop_spinner
      @spinner.stop if @spinner.spinning?
    end

    # Flush any in-progress content phase.
    def flush_content
      if @current_phase.is_a?(Phase::ContentPhase)
        @current_phase.finish
        @last_output = :content unless @current_phase.empty?
      end
    end

    # Reset state for a new execution.
    def reset!
      @current_phase = nil
      @last_output   = nil
      @streamer.reset
    end

    private

      # ── Event Callbacks ──

      def on_content(text)
        stop_spinner
        unless @current_phase.is_a?(Phase::ContentPhase)
          @terminal.buffer << @terminal.separator unless @last_output == :separator
          @current_phase = Phase::ContentPhase.new(@streamer)
        end
        @current_phase.append(text)
        @last_output = :content
      end

      def on_reasoning(_text); end

      # Receives the full batch of tool calls for this LLM turn.
      # Renders all tool call headers upfront.
      def on_tool_call_start(calls)
        stop_spinner
        flush_content

        @current_phase = Phase::ToolPhase.new(calls)

        @terminal.buffer << @terminal.separator unless @last_output == :separator
        @terminal.buffer.print SAVE_CURSOR
        render_tool_phase
        @last_output = :tool

        start_spinner
      end

      # Fires once per tool as each completes.
      # Re-renders the entire tool phase block.
      def on_tool_result(name, result)
        stop_spinner

        if @current_phase.is_a?(Phase::ToolPhase)
          @current_phase.resolve(name, result)

          @terminal.buffer.print RESTORE_CURSOR
          @terminal.buffer.print CLEAR_TO_END
          render_tool_phase
          @last_output = :tool
          start_spinner
        end
      end

      # ── Rendering ──

      def render_tool_phase
        @current_phase.tool_calls.each do |call|
          @terminal.buffer << ToolOutput.for(call, width: @terminal.width)
        end
      end
  end
end
