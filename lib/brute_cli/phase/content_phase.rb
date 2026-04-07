# frozen_string_literal: true

module BruteCLI
  module Phase
    # Accumulates streamed text tokens. Owns a StreamFormatter for
    # incremental terminal output.
    class ContentPhase
      attr_reader :buf

      def initialize(streamer)
        @streamer = streamer
        @buf = +""
      end

      def append(text)
        @buf << text
        @streamer << text
      end

      def finish
        return if @buf.strip.empty?
        @streamer.flush
        @buf = +""
      end

      def empty? = @buf.strip.empty?
    end
  end
end
