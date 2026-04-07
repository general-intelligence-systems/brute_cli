# frozen_string_literal: true

RSpec.describe BruteCLI::BufferOutput::Separator do
  describe '#to_s' do
    it 'returns a thin separator by default' do
      result = described_class.new(width: 80).to_s
      expect(result).to include("\u2500")
      expect(result).not_to include("\u2550")
    end

    it 'returns a thick separator when thick: true' do
      result = described_class.new(width: 80, thick: true).to_s
      expect(result).to include("\u2550")
      expect(result).not_to include("\u2500")
    end

    it 'uses width for character count' do
      plain = described_class.new(width: 50).to_s.gsub(/\e\[[0-9;]*m/, '')
      expect(plain.length).to eq(50)
    end

    it 'enforces a minimum width of 40' do
      plain = described_class.new(width: 10).to_s.gsub(/\e\[[0-9;]*m/, '')
      expect(plain.length).to eq(40)
    end

    it 'works with puts' do
      output = capture_stdout { puts described_class.new(width: 80) }
      expect(output).to include("\u2500")
      expect(output).to end_with("\n")
    end
  end
end
