# frozen_string_literal: true

require "bundler/setup"
require "brute_cli"

module BruteCLI
  class REPL
    # Registry of slash commands available in the REPL.
    #
    # Each command maps to a method name on the REPL instance.
    # Reline's completion_proc uses +names+ to offer autocomplete suggestions
    # when the user types "/" at the start of a line.
    #
    module Commands
      Entry = Struct.new(:name, :description, :method_name, keyword_init: true)

      REGISTRY = [
        Entry.new(name: "/menu",     description: "Open main menu",          method_name: :cmd_menu),
        Entry.new(name: "/model",    description: "Change model",            method_name: :cmd_model),
        Entry.new(name: "/provider", description: "Change provider",         method_name: :cmd_provider),
        Entry.new(name: "/help",     description: "Show available commands", method_name: :cmd_help),
        Entry.new(name: "/compact",  description: "Compact conversation",    method_name: :cmd_compact),
        Entry.new(name: "/exit",     description: "Exit brute",             method_name: :cmd_exit),
      ].freeze

      # All command names, for Reline completion.
      def self.names
        REGISTRY.map(&:name)
      end

      # Does this input look like a slash command?
      def self.match?(input)
        input.strip.start_with?("/")
      end

      # Find the matching Entry for the given input, or nil.
      def self.find(input)
        cmd = input.strip.split(/\s+/, 2).first
        REGISTRY.detect { |e| e.name == cmd }
      end
    end
  end
end
