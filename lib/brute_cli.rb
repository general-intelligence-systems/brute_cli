# frozen_string_literal: true

require 'brute'

begin
  require 'brute_flow'
rescue LoadError
end

require 'tty-screen'
require 'tty-spinner'
require 'brute_cli/version'
require 'brute_cli/styles'
require 'brute_cli/emoji'
require 'brute_cli/bat'
require 'brute_cli/stream_formatter'
require 'brute_cli/fzf_menu'
require 'brute_cli/commands'
require 'brute_cli/repl'

module BruteCLI
  LOGO = <<-LOGO
 .o8                                .             
"888                              .o8             
 888oooo.  oooo d8b oooo  oooo  .o888oo  .ooooo.  
 d88' `88b `888""8P `888  `888    888   d88' `88b 
 888   888  888      888   888    888   888ooo888 
 888   888  888      888   888    888 . 888    .o 
 `Y8bod8P' d888b     `V88V"V8P'   "888" `Y8bod8P' 
  LOGO

  # yolo, bruv...

  def self.error(message)
    $stderr.puts "#{"ERROR".colorize(ERROR_BG)} #{message.colorize(ERROR_FG)}"
  end

  def self.warn(message)
    $stderr.puts "warning: #{message}".colorize(DIM)
  end
end
