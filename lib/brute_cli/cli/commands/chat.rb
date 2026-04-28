# frozen_string_literal: true

require "bundler/setup"
require "brute_cli"
require "dry/cli"

module BruteCLI
  module CLI
    module Commands
      class Chat < Dry::CLI::Command
        desc "Start a chat session or run a single prompt"

        argument :prompt, required: false, desc: "Prompt text (omit for interactive REPL)"

        option :directory, aliases: ["-d"], desc: "Working directory"
        option :session,   aliases: ["-s"], desc: "Resume a session by ID"

        def call(prompt: nil, **options)
          opts = {}
          opts[:session_id] = options[:session] if options[:session]

          if options[:directory]
            Dir.chdir(options[:directory])
          end

          if prompt
            # Single-shot mode: run the prompt and exit.
            Execution.new(opts).run(prompt)
          else
            # Interactive REPL mode.
            REPL.new(opts).run
          end
        end
      end
    end
  end
end
