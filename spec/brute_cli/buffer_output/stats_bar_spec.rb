# frozen_string_literal: true

RSpec.describe BruteCLI::BufferOutput::StatsBar do
  let(:metadata) do
    {
      tokens: { total: 150, total_input: 100, total_output: 50 },
      timing: { total_elapsed: 45.5 },
      tool_calls: 5,
    }
  end

  describe '#to_s' do
    it 'includes token counts' do
      result = described_class.new(metadata, width: 80).to_s
      expect(result).to include('tokens')
      expect(result).to include('150')
      expect(result).to include('100')
      expect(result).to include('50')
    end

    it 'includes timing' do
      result = described_class.new(metadata, width: 80).to_s
      expect(result).to include('time')
      expect(result).to include('45.5s')
    end

    it 'includes tool count when > 0' do
      result = described_class.new(metadata, width: 80).to_s
      expect(result).to include('tools')
      expect(result).to include('5')
    end

    it 'omits tool count when 0' do
      meta = metadata.merge(tool_calls: 0)
      result = described_class.new(meta, width: 80).to_s
      expect(result).not_to include('tools')
    end

    it 'handles missing metadata gracefully' do
      result = described_class.new({}, width: 80).to_s
      expect(result).to include('tokens')
      expect(result).to include('0')
    end

    it 'formats time over 60s as minutes' do
      meta = metadata.merge(timing: { total_elapsed: 90.3 })
      result = described_class.new(meta, width: 80).to_s
      expect(result).to include('1m30.3s')
    end

    it 'works with puts' do
      output = capture_stdout { puts described_class.new(metadata, width: 80) }
      expect(output).to include('tokens')
    end
  end
end
