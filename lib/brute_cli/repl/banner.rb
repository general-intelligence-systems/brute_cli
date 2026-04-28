# frozen_string_literal: true

require "bundler/setup"
require "brute_cli"

module BruteCLI
  class REPL
    # Pure-data renderer for the startup banner.
    # Receives the terminal and display data — no live Execution reference.
    class Banner
      def initialize(terminal:, session_id: nil, session_path: nil)
        @terminal = terminal
        @session_id = session_id
        @session_path = session_path
        print_banner
      end

      private

      def print_banner
        buf = @terminal.buffer

        buf << @terminal.separator
        buf << BruteCLI::MONIKER.chomp.colorize(DIM)
        buf << @terminal.separator
        buf << "Version #{Brute::VERSION} | cli: #{BruteCli::VERSION}".colorize(DIM)

        if @session_id
          session_dir = @session_path ? File.dirname(@session_path) : nil
          buf << @terminal.separator
          buf << "session_id:  ".colorize(DIM) + @session_id.colorize(ACCENT)
          buf << "session_log: ".colorize(DIM) + session_dir.colorize(ACCENT) if session_dir
        end

        check_dependencies
        buf << @terminal.separator
        buf << "Type /help for available commands.".colorize(DIM)
        buf << @terminal.separator
      end

      def check_dependencies
        missing = []
        missing << ["bat",  "https://github.com/sharkdp/bat#installation", "diff syntax highlighting"]  unless BruteCLI::Bat.available?
        missing << ["fzf",  "https://github.com/junegunn/fzf#installation", "interactive selection"]    unless fzf_on_path?
        return if missing.empty?

        @terminal.buffer << @terminal.separator
        missing.each do |name, url, purpose|
          @terminal.buffer.warn " #{name} not found — recommended for #{purpose}.\n Install: #{url} ".colorize(background: :red, color: :white)
        end
      end

      def fzf_on_path?
        ENV["PATH"].to_s.split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, "fzf")) }
      end
    end
  end
end
