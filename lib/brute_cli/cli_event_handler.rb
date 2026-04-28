# frozen_string_literal: true

require "console"
require "fileutils"

module BruteCLI
  class CLIEventHandler < Brute::Events::Handler
    SAVE_CURSOR    = "\e7"
    RESTORE_CURSOR = "\e8"
    CLEAR_TO_END   = "\e[J"

    DEBUG_LOG = File.join(Dir.home, ".brute", "debug.log")

    attr_reader :metadata

    def initialize(inner, terminal:, spinner:, streamer:)
      super(inner)
      @terminal = terminal
      @spinner  = spinner
      @streamer = streamer
      @metadata = { tokens: {}, timing: {}, tool_calls: 0 }
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
        calls = data.map do |tc|
          { name: tc[:name], arguments: tc[:arguments] }
        end
        on_tool_call_start(calls)

      when :tool_result
        on_tool_result(data[:name], data[:content])

      when :log, :error, :assistant_complete
        # ignored
      end

      super
    end

    def start_spinner
      stop_spinner

      @spinner.start
    end

    def stop_spinner
      @spinner.stop if @spinner.spinning?
    end

    def pause_spinner(&block)
      stop_spinner
      yield
      start_spinner
    end

    # Flush any buffered streamed content through the markdown renderer.
    # Call at the end of an agent turn, before printing stats.
    def flush_content
      @streamer.flush
    end

    # Reset streamer state for the next agent turn.
    def reset_content
      @streamer.reset
    end

    private

      def on_content(text)
        pause_spinner do
          @streamer << text
        end
      end

      def on_reasoning(text)
        # no op
      end

      def on_tool_call_start(tools)
        pause_spinner do
          tools.each do |tool|
            output = ToolOutput.for(name: tool[:name], args: tool[:arguments], width: @terminal.width)
            puts output.header
          end
        end
      end

      SILENT_TOOLS = %w[delegate].freeze

      def on_tool_result(name, result)
        pause_spinner do
          icon = ToolOutput.icon_for(name)
          if SILENT_TOOLS.include?(name.to_s)
            puts "#{icon} #{name} #{"done".colorize(:green)}"
          else
            puts "#{icon} #{name} #{result}"
          end
        end
      end
  end
end
