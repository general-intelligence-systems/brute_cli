# frozen_string_literal: true


require "bundler/setup"
require "brute_cli"
require "dry/cli"
require "brute_cli/cli/commands/chat"
require "brute_cli/cli/commands/sessions"
require "brute_cli/cli/commands/version"

module BruteCLI
  module CLI
    module Commands
      extend Dry::CLI::Registry

      register "chat",     Chat
      register "sessions", Sessions
      register "version",  Version, aliases: ["v", "-v", "--version"]
    end
  end
end
