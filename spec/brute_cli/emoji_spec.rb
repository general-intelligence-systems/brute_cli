# frozen_string_literal: true

RSpec.describe BruteCLI::Emoji do
  describe '.find' do
    it 'returns the emoji for a known alias' do
      result = described_class.find('eyes')
      expect(result).to be_a(String)
      expect(result).not_to be_empty
    end

    it 'returns empty string for unknown alias' do
      result = described_class.find('nonexistent_emoji_alias')
      expect(result).to eq('')
    end
  end

  describe 'constants' do
    it 'has all expected emoji constants as non-empty strings' do
      constants = %i[
        EYES PENCIL PAGE COMPUTER SPARKLES GLOBE WASTEBASKET REWIND
        DIAMOND GEAR MAG HAMMER PACKAGE CLIPBOARD CHECK CROSS
        WRITING ROBOT FOLDER
      ]

      constants.each do |const|
        value = described_class.const_get(const)
        expect(value).to be_a(String)
        expect(value).not_to be_empty
      end
    end
  end
end
