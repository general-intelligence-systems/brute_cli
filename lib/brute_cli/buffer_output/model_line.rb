# frozen_string_literal: true

require "brute_cli/styles"

module BruteCLI
  module BufferOutput
    # Renderable provider / model / agent status line.
    #
    #   puts BufferOutput::ModelLine.new(
    #     provider_name: "anthropic",
    #     model_short:   "3.5-sonnet",
    #     current_agent: "build"
    #   )
    #   # => "anthropic 3.5-sonnet · agent build"
    #
    class ModelLine
      def initialize(provider_name:, model_short:, current_agent:)
        @provider_name = provider_name
        @model_short = model_short
        @current_agent = current_agent
      end

      def to_s
        parts = []
        parts << stat_span(@provider_name, @model_short) if @provider_name && @model_short
        parts << stat_span("agent", @current_agent)
        parts.join(" \u00b7 ".colorize(DIM))
      end

      private

      def stat_span(label, value)
        "#{label} ".colorize(DIM) + value.to_s.colorize(ACCENT)
      end
    end
  end
end
