# frozen_string_literal: true

module BruteCLI
  module ToolOutput
    class Base
      include BruteCLI

      ICON = Emoji::GEAR

      TODO_STATUS = {
        "pending"     => Emoji::SQUARE,
        "in_progress" => Emoji::ARROWS,
        "completed"   => Emoji::CHECK,
        "cancelled"   => Emoji::CROSS,
      }.freeze

      def initialize(tool_call, width:)
        @call   = tool_call
        @width  = width
        @args   = normalize_args(@call.arguments)
        @result = @call.result
      end

      def to_s
        lines = [header_line]
        if @call.resolved?
          lines.concat(body_lines)
          lines.concat(error_lines) if error?
        end
        lines.join("\n")
      end

      private

      def icon    = self.class::ICON
      def name    = @call.name.to_s

      def header_line
        "#{icon} #{name.colorize(ACCENT_BG)} #{summary}".rstrip
      end

      def summary = ""

      def body_lines
        [] # subclasses override
      end

      # ── Shared helpers ──

      def arg(key)
        @args[key.to_s] || @args[key.to_sym]
      end

      def result_val(key)
        @result.is_a?(Hash) && (@result[key.to_s] || @result[key.to_sym])
      end

      def error?
        @result.is_a?(Hash) && (@result[:error] || @result["error"])
      end

      def error_lines
        msg = error_message
        msg = msg[0..70] + "..." if msg.length > 70
        ["#{"FAILED".colorize(ERROR_BG)} #{msg.colorize(DIM)}"]
      end

      def error_message
        if @result.is_a?(Hash)
          (
            @result[:message]  ||
            @result["message"] ||
            @result[:error]    ||
            @result["error"]
          ).to_s
        else
          ""
        end
      end

      def diff_lines
        diff = result_val(:diff)
        if diff && !diff.to_s.strip.empty?
          [BruteCLI::Bat.diff_mode(diff, width: @width).chomp]
        else
          []
        end
      end

      def todo_lines(todos)
        return [] unless todos && !todos.empty?

        todos.map do |t|
          t = t.transform_keys(&:to_s) if t.is_a?(Hash)
          status  = t["status"].to_s
          ico     = TODO_STATUS[status] || Emoji::SQUARE
          content = t["content"] || t["id"] || "?"
          "  #{ico} #{content}"
        end
      end

      def normalize_args(args)
        args.is_a?(Hash) ? args : {}
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

    # Returns a ToolOutput instance for the given ToolCall.
    def self.for(tool_call, width: 80)
      klass = MAP[tool_call.name.to_s] || Base
      klass.new(tool_call, width: width)
    end
  end
end
