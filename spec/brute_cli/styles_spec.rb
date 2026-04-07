# frozen_string_literal: true

RSpec.describe "BruteCLI color constants" do
  it "defines COLOR as a valid colorize color symbol" do
    expect(BruteCLI::COLOR).to be_a(Symbol)
    expect(String.colors).to include(BruteCLI::COLOR)
  end

  it "defines DIM as a colorize color symbol" do
    expect(BruteCLI::DIM).to eq(:light_black)
  end

  it "defines ACCENT equal to COLOR" do
    expect(BruteCLI::ACCENT).to eq(BruteCLI::COLOR)
  end

  it "defines ACCENT_BOLD as a hash with color and mode" do
    expect(BruteCLI::ACCENT_BOLD).to include(color: BruteCLI::COLOR, mode: :bold)
  end

  it "defines ACCENT_BG with background set to COLOR" do
    expect(BruteCLI::ACCENT_BG).to include(background: BruteCLI::COLOR)
  end

  it "defines ERROR_BG with red background" do
    expect(BruteCLI::ERROR_BG).to include(background: :red)
  end

  it "defines ERROR_FG as :red" do
    expect(BruteCLI::ERROR_FG).to eq(:red)
  end

  describe "colorize integration" do
    it "applies DIM to a string" do
      result = "hello".colorize(BruteCLI::DIM)
      expect(result).to include("hello")
      expect(result).to include("\e[")
    end

    it "applies ACCENT_BOLD to a string" do
      result = "prompt".colorize(BruteCLI::ACCENT_BOLD)
      expect(result).to include("prompt")
      expect(result).to include("\e[")
    end

    it "applies ERROR_BG to a string" do
      result = "ERROR".colorize(BruteCLI::ERROR_BG)
      expect(result).to include("ERROR")
      expect(result).to include("\e[")
    end
  end

  describe "THEMES" do
    it "maps theme names to colorize color symbols" do
      BruteCLI::THEMES.each do |name, color|
        expect(color).to be_a(Symbol)
        expect(String.colors).to include(color), "#{name} maps to #{color} which is not a valid colorize color"
      end
    end

    it "includes the expected themes" do
      expect(BruteCLI::THEMES.keys).to contain_exactly(
        "lemon-and-lime", "ganja-king", "og-treacle",
        "blues-clues", "hot-cheeto", "blue-ice-vape",
        "matrix", "mrs-jackson"
      )
    end

    it "maps lemon-and-lime to yellow" do
      expect(BruteCLI::THEMES["lemon-and-lime"]).to eq(:yellow)
    end

    it "maps ganja-king to green" do
      expect(BruteCLI::THEMES["ganja-king"]).to eq(:green)
    end

    it "maps og-treacle to magenta" do
      expect(BruteCLI::THEMES["og-treacle"]).to eq(:magenta)
    end

    it "maps blues-clues to blue" do
      expect(BruteCLI::THEMES["blues-clues"]).to eq(:blue)
    end

    it "maps hot-cheeto to light_red" do
      expect(BruteCLI::THEMES["hot-cheeto"]).to eq(:light_red)
    end

    it "maps blue-ice-vape to light_magenta" do
      expect(BruteCLI::THEMES["blue-ice-vape"]).to eq(:light_magenta)
    end

    it "maps matrix to light_green" do
      expect(BruteCLI::THEMES["matrix"]).to eq(:light_green)
    end

    it "maps mrs-jackson to red" do
      expect(BruteCLI::THEMES["mrs-jackson"]).to eq(:red)
    end
  end

  describe ".apply_theme!" do
    after { BruteCLI.apply_theme!(BruteCLI::DEFAULT_THEME) }

    it "switches accent constants to the theme color" do
      BruteCLI.apply_theme!("ganja-king")

      expect(BruteCLI::COLOR).to eq(:green)
      expect(BruteCLI::ACCENT).to eq(:green)
      expect(BruteCLI::ACCENT_BOLD).to include(color: :green, mode: :bold)
      expect(BruteCLI::ACCENT_BG).to include(background: :green)
      expect(BruteCLI::ACCENT_BG2).to include(background: :green)
    end

    it "does not affect error constants" do
      BruteCLI.apply_theme!("og-treacle")

      expect(BruteCLI::ERROR_BG).to include(background: :red)
      expect(BruteCLI::ERROR_FG).to eq(:red)
    end

    it "raises on unknown theme" do
      expect { BruteCLI.apply_theme!("unknown") }.to raise_error(ArgumentError, /Unknown theme/)
    end
  end
end
