# frozen_string_literal: true

require 'brute'

begin # why?
  require 'brute_flow'
rescue LoadError
end

require 'tty-screen'

module BruteCLI
  MONIKER = <<~MONIKER
    .o8                                .             
   "888                              .o8             
    888oooo.  oooo d8b oooo  oooo  .o888oo  .ooooo.  
    d88' `88b `888""8P `888  `888    888   d88' `88b 
    888   888  888      888   888    888   888ooo888 
    888   888  888      888   888    888 . 888    .o 
    `Y8bod8P' d888b     `V88V"V8P'   "888" `Y8bod8P' 
  MONIKER

  # museum of modern art, bruv...

  def self.error(message)
    $stderr.puts "#{"ERROR".colorize(ERROR_BG)} #{message.colorize(ERROR_FG)}"
  end

  def self.warn(message)
    $stderr.puts "warning: #{message}".colorize(DIM)
  end
end

Dir.glob("#{__dir__}/brute_cli/**/*.rb").sort.each do |path|
  require path
end

