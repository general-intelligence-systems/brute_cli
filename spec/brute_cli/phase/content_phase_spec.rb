# frozen_string_literal: true

RSpec.describe BruteCLI::Phase::ContentPhase do
  let(:sink) { StringIO.new }
  let(:streamer) { BruteCLI::StreamFormatter.new(output: sink) }
  let(:phase) { described_class.new(streamer) }

  describe '#append' do
    it 'accumulates text in the buffer' do
      phase.append("hello ")
      phase.append("world")
      expect(phase.buf).to eq("hello world")
    end

    it 'streams text to the streamer' do
      phase.append("hi")
      expect(sink.string).to include("hi")
    end
  end

  describe '#empty?' do
    it 'is true when buffer is empty' do
      expect(phase.empty?).to be true
    end

    it 'is true when buffer is whitespace only' do
      phase.append("   ")
      expect(phase.empty?).to be true
    end

    it 'is false when buffer has content' do
      phase.append("hello")
      expect(phase.empty?).to be false
    end
  end

  describe '#finish' do
    it 'flushes the streamer and clears the buffer' do
      phase.append("hello")
      phase.finish
      expect(phase.buf).to eq("")
    end

    it 'does nothing when buffer is whitespace only' do
      phase.append("  ")
      phase.finish
      expect(phase.buf).to eq("  ") # unchanged — finish is a no-op
    end
  end
end
