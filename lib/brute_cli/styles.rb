# frozen_string_literal: true

require 'lipgloss'

module BruteCLI
  module Styles
    # Styles.foreground("#fff").bold(true) etc -- delegates to Lipgloss::Style.new
    def self.method_missing(name, *args, &block)
      Lipgloss::Style.new.send(name, *args, &block)
    end

    def self.respond_to_missing?(name, include_private = false)
      Lipgloss::Style.new.respond_to?(name) || super
    end

    # Brand colors
    PURPLE  = '#6B50FF'
    PINK    = '#FF60FF'
    CYAN    = '#3EEFCF'
    RED     = '#FF5F87'
    DIM     = '#757575'
    MUTED   = '#585858'
    WHITE   = '#F1F1F1'
    DARK_BG = '#1A1A2E'

    PROMPT       = foreground(PURPLE).bold(true)
    DIM_TEXT     = foreground(DIM)
    SEPARATOR    = foreground(MUTED)
    STAT_VALUE   = foreground(CYAN)
    ERROR_BADGE  = foreground(WHITE).background(RED).bold(true).padding_left(1).padding_right(1)
    ERROR_REASON = foreground(RED)
    TOOL_BADGE   = foreground(DARK_BG).background(CYAN).bold(true).padding_left(1).padding_right(1)
    TOOL_ARG_KEY = foreground(PURPLE)
    TOOL_ARG_VAL = foreground(DIM)
    TOOL_OK      = foreground(DARK_BG).background(CYAN).padding_left(1).padding_right(1)
    TOOL_FAIL    = foreground(WHITE).background(RED).bold(true).padding_left(1).padding_right(1)
    TOOL_FRAME   = border_style(:rounded).border_foreground(MUTED).padding_left(1).padding_right(1)
  end
end
