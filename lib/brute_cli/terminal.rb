# frozen_string_literal: true

require "tty-screen"
require "brute_cli/buffer_output"

module BruteCLI
  # Single owner of all terminal output.  Every object that needs to write
  # to the terminal receives a Terminal instance and writes through its
  # buffer — nothing calls puts/print/$stdout directly.
  #
  #   terminal = Terminal.new
  #   terminal.buffer << "hello"          # prints with newline
  #   terminal.buffer.print "\e7"         # raw print, no newline
  #   terminal.buffer.warn "uh oh"        # prints to stderr
  #
  class Terminal
    attr_reader :buffer

    def initialize
      @buffer = Buffer.new
    end

    def width
      TTY::Screen.width
    end

    def separator(thick: false)
      BufferOutput::Separator.new(width: width, thick: thick)
    end

    # Passthrough buffer — for now every write goes straight to the IO.
    # This is the ONLY object allowed to touch $stdout / $stderr.
    #
    # When no explicit IO is provided, delegates to $stdout / $stderr at
    # call time (not construction time) so test IO swaps work correctly.
    class Buffer
      def initialize(out: nil, err: nil)
        @out = out
        @err = err
      end

      # Primary output — appends text with a trailing newline (like puts).
      def <<(text)
        out.puts(text)
        self
      end

      # Raw output — no trailing newline (for escape sequences, etc.).
      def print(text)
        out.print(text)
        self
      end

      # Stderr output.
      def warn(text)
        err.puts(text)
        self
      end

      def flush
        out.flush
        self
      end

      # Expose the underlying IO so TTY::Spinner and StreamFormatter
      # can use it as their output target.
      def io
        out
      end

      private

      def out
        @out || $stdout
      end

      def err
        @err || $stderr
      end
    end
  end
end
