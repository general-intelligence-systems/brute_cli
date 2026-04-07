# frozen_string_literal: true

module BruteCLI
  module ToolOutput
    class Fetch < Base
      ICON = Emoji::GLOBE

      private

      def summary
        url = arg(:url)
        url ? url.to_s.colorize(DIM) : ""
      end
    end
  end
end
