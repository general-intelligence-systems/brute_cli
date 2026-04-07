# frozen_string_literal: true

require "brute_cli/styles"

module BruteCLI
  module BufferOutput
    # Renderable token / timing / tool-call metrics line.
    #
    #   puts BufferOutput::StatsBar.new(metadata, width: 80)
    #   # => "tokens 150 | in 100 | out 50 | time 45.5s | tools 5"
    #
    class StatsBar
      def initialize(metadata, width:)
        @metadata = metadata
        @width = width
      end

      def to_s
        tokens = @metadata[:tokens] || {}
        timing = @metadata[:timing] || {}
        tool_calls = @metadata[:tool_calls] || 0
        sep = " | ".colorize(DIM)
        parts = []
        parts << stat_span("tokens", (tokens[:total] || 0).to_s)
        parts << stat_span("in", (tokens[:total_input] || 0).to_s)
        parts << stat_span("out", (tokens[:total_output] || 0).to_s)
        parts << stat_span("time", format_time(timing[:total_elapsed] || 0))
        parts << stat_span("tools", tool_calls.to_s) if tool_calls > 0
        parts.join(sep)
      end

      private

      def stat_span(label, value)
        "#{label} ".colorize(DIM) + value.to_s.colorize(ACCENT)
      end

      def format_time(s)
        s < 60 ? "#{s.round(1)}s" : "#{(s / 60).floor}m#{(s % 60).round(1)}s"
      end
    end
  end
end
