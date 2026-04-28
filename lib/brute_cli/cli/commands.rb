# frozen_string_literal: true

require "dry/cli"
require_relative "commands/chat"
require_relative "commands/sessions"
require_relative "commands/version"

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
