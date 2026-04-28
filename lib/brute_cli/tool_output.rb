# frozen_string_literal: true

module BruteCLI
  module ToolOutput
    class Base
      include BruteCLI

      ICON = Emoji::GEAR

      def initialize(name:, args: {}, width: 80)
        @name  = name.to_s
        @args  = args.is_a?(Hash) ? args : {}
        @width = width
      end

      # Icon + colorized name + summary (file path, command, etc.)
      def header
        "#{icon} #{@name.colorize(ACCENT_BG)} #{summary}".rstrip
      end

      private

      def icon = self.class::ICON

      def summary = ""

      def arg(key)
        @args[key.to_s] || @args[key.to_sym]
      end
    end

    require_relative "tool_output/read"
    require_relative "tool_output/write"
    require_relative "tool_output/patch"
    require_relative "tool_output/shell"
    require_relative "tool_output/fs_search"
    require_relative "tool_output/fetch"
    require_relative "tool_output/remove"
    require_relative "tool_output/undo"
    require_relative "tool_output/delegate"
    require_relative "tool_output/question"
    require_relative "tool_output/todo_read"
    require_relative "tool_output/todo_write"

    MAP = {
      "read"       => Read,
      "write"      => Write,
      "patch"      => Patch,
      "shell"      => Shell,
      "fs_search"  => FsSearch,
      "fetch"      => Fetch,
      "remove"     => Remove,
      "undo"       => Undo,
      "delegate"   => Delegate,
      "question"   => Question,
      "todo_read"  => TodoRead,
      "todo_write" => TodoWrite,
    }.freeze

    # Build a ToolOutput instance by name.
    def self.for(name:, args: {}, width: 80)
      klass = MAP[name.to_s] || Base
      klass.new(name: name, args: args, width: width)
    end

    # Just the icon for a given tool name.
    def self.icon_for(name)
      klass = MAP[name.to_s] || Base
      klass::ICON
    end
  end
end
