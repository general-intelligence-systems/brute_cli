# frozen_string_literal: true

RSpec.describe BruteCLI::BufferOutput::ModelLine do
  describe '#to_s' do
    it 'includes provider, model, and agent' do
      line = described_class.new(
        provider_name: 'anthropic',
        model_short: '3.5-sonnet',
        current_agent: 'build',
      )
      result = line.to_s
      expect(result).to include('anthropic')
      expect(result).to include('3.5-sonnet')
      expect(result).to include('build')
    end

    it 'omits provider span when provider_name is nil' do
      line = described_class.new(
        provider_name: nil,
        model_short: nil,
        current_agent: 'build',
      )
      result = line.to_s
      expect(result).to include('build')
      expect(result).not_to include('anthropic')
    end

    it 'omits provider span when model_short is nil' do
      line = described_class.new(
        provider_name: 'anthropic',
        model_short: nil,
        current_agent: 'build',
      )
      result = line.to_s
      expect(result).not_to include('anthropic')
      expect(result).to include('build')
    end

    it 'works with puts' do
      line = described_class.new(
        provider_name: 'openai',
        model_short: 'gpt-4',
        current_agent: 'plan',
      )
      output = capture_stdout { puts line }
      expect(output).to include('openai')
      expect(output).to include('gpt-4')
      expect(output).to include('plan')
    end
  end
end
