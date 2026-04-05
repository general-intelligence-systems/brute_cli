# frozen_string_literal: true

require "brute"
require "colorize"
require "emoji"

# Optionally load brute_flow if available.
begin
  require "brute_flow"
rescue LoadError
  # brute_flow is optional for CLI usage
end

module BruteCLI
  VERSION = "0.1.0"

  CROSS_MARK   = Emoji.find_by_alias("x").raw
  WARNING_SIGN = Emoji.find_by_alias("warning").raw

  # Print a red error message with a cross mark prefix to stderr.
  def self.error(message)
    $stderr.puts "#{CROSS_MARK} #{message}".red
  end

  # Print a yellow warning to stderr.
  def self.warn(message)
    $stderr.puts "#{WARNING_SIGN} #{message}".yellow
  end
end
