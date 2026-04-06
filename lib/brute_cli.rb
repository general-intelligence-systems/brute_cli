# frozen_string_literal: true

require 'brute'

begin
  require 'brute_flow'
rescue LoadError
end

require 'tty-spinner'
require 'lipgloss'
require 'glamour'

require 'brute_cli/version'
require 'brute_cli/styles'
require 'brute_cli/emoji'
require 'brute_cli/repl'

module BruteCLI
  def self.error(message)
    warn "#{Styles::ERROR_BADGE.render('ERROR')} #{Styles::ERROR_REASON.render(message)}"
  end

  def self.warn(message)
    warn Styles::DIM_TEXT.render("warning: #{message}")
  end
end
