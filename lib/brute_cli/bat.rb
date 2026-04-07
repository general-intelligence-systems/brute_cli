# frozen_string_literal: true

require "open3"

module BruteCLI
  # Thin wrapper around the `bat` command for syntax-highlighted terminal output.
  # Provides two rendering modes: one for unified diffs and one for markdown prose.
  module Bat
    BAT_BIN = ENV.fetch("BRUTE_BAT_BIN", "bat")

    COMMON_FLAGS = %w[
      --color=always
      --paging=never
    ].freeze

    # Render a unified diff with line numbers and a grid border.
    #
    #   BruteCLI::Bat.diff_mode(patch_text, width: 100)
    #
    def self.diff_mode(text, width: 80)
      run(text, language: "diff", style: "numbers,grid", width: width)
    end

    # Render markdown source with syntax highlighting (headers, bold, fenced
    # code blocks, etc.) — no extra decorations so it reads like prose.
    #
    #   BruteCLI::Bat.markdown_mode(md_text, width: 120)
    #
    def self.markdown_mode(text, width: 80)
      run(text, language: "markdown", style: "plain", width: width)
    end

    # Returns true if the bat binary is found on PATH.
    def self.available?
      return @available if defined?(@available)
      @available = ENV["PATH"].to_s.split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, BAT_BIN)) }
    end

    # Low-level: pipe +text+ through bat with arbitrary options.
    def self.run(text, language:, style:, width: 80)
      cmd = [
        BAT_BIN,
        *COMMON_FLAGS,
        "--language=#{language}",
        "--style=#{style}",
        "--terminal-width=#{width}",
      ]

      stdout, status = Open3.capture2(*cmd, stdin_data: text)

      if status.success?
        stdout
      else
        # If bat exits non-zero, return the raw text so we never swallow output.
        text
      end
    rescue Errno::ENOENT
      unless @bat_missing_warned
        msg = " bat not found — diff syntax highlighting unavailable.\n" \
              " Install: https://github.com/sharkdp/bat#installation "
        $stderr.puts msg.colorize(background: :red, color: :white)
        @bat_missing_warned = true
      end
      text
    end
  end
end
