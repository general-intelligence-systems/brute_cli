# frozen_string_literal: true

require "colorize"

module BruteCLI
  # Available themes — each maps to a colorize color symbol.
  THEMES = {
    "lemon-and-lime" => :yellow,
    "ganja-king"     => :green,
    "og-treacle"     => :magenta,
    "blues-clues"    => :blue,
    "hot-cheeto"     => :light_red,
    "blue-ice-vape"  => :light_magenta,
    "matrix"         => :light_green,
    "mrs-jackson"    => :red,
  }.freeze

  DEFAULT_THEME = "lemon-and-lime"

  # Global accent color — change this one constant to re-theme the entire CLI.
  COLOR = THEMES.fetch(DEFAULT_THEME)

  # Named color/style constants for use with "string".colorize(CONST).
  # Compound styles (bold + color, background + foreground) use the hash form.
  DIM         = :grey
  ACCENT      = COLOR
  ACCENT_BOLD = { color: COLOR, mode: :bold }
  ACCENT_BG   = { color: :black, background: COLOR, mode: :bold }
  ACCENT_BG2  = { color: :black, background: COLOR }
  ERROR_BG    = { color: :white, background: :red, mode: :bold }
  ERROR_FG    = :red

  # Re-derive all accent constants from a new color.
  # Call this before any output (e.g. right after option parsing).
  def self.apply_theme!(name)

    # honestly what the fuck is this shit???????????
  
    color = THEMES.fetch(name) do
      raise ArgumentError, "Unknown theme #{name.inspect}. Valid themes: #{THEMES.keys.join(', ')}"
    end

    remove_const(:COLOR)       ; const_set(:COLOR,       color)
    remove_const(:ACCENT)      ; const_set(:ACCENT,      color)
    remove_const(:ACCENT_BOLD) ; const_set(:ACCENT_BOLD, { color: color, mode: :bold })
    remove_const(:ACCENT_BG)   ; const_set(:ACCENT_BG,   { color: :black, background: color, mode: :bold })
    remove_const(:ACCENT_BG2)  ; const_set(:ACCENT_BG2,  { color: :black, background: color })
  end
end
