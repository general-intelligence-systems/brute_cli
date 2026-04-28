# frozen_string_literal: true

require "dry/cli"

module BruteCLI
  module CLI
    module Commands
      class Version < Dry::CLI::Command
        desc "Print version"

        def call(**)
          puts "brute #{BruteCli::VERSION}"
        end
      end
    end
  end
end
