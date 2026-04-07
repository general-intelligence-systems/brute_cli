# frozen_string_literal: true

RSpec.describe BruteCLI::Spinner::Nyan do
  subject(:spinner) { described_class.new }

  describe '#label' do
    it 'returns "Thinking..."' do
      expect(spinner.label).to eq("Thinking...")
    end
  end

  describe '#frames' do
    it 'returns 12 frames' do
      expect(spinner.frames.size).to eq(12)
    end

    it 'each frame contains ANSI color codes and bar characters' do
      spinner.frames.each do |frame|
        expect(frame).to include("\e[")
        expect(frame).to include('━')
      end
    end

    it 'has 7 unique frames (based on 7 rainbow colors)' do
      expect(spinner.frames.uniq.size).to eq(7)
    end
  end

  describe '#interval' do
    it 'returns 8' do
      expect(spinner.interval).to eq(8)
    end
  end

  describe 'RAINBOW constant' do
    it 'has 7 ANSI 24-bit color codes' do
      expect(described_class::RAINBOW.size).to eq(7)
      described_class::RAINBOW.each do |code|
        expect(code).to match(/\A\e\[38;2;\d+;\d+;\d+m\z/)
      end
    end
  end

  describe '#spinning?' do
    it 'returns false when not started' do
      expect(spinner.spinning?).to be false
    end
  end

  describe '#stop' do
    it 'is safe to call when not started' do
      expect { spinner.stop }.not_to raise_error
    end
  end

  describe '#start / #stop lifecycle' do
    it 'starts and stops a TTY::Spinner' do
      tty = instance_double(TTY::Spinner, auto_spin: nil, spinning?: true, stop: nil)
      allow(TTY::Spinner).to receive(:new).and_return(tty)

      spinner.start
      expect(tty).to have_received(:auto_spin)

      allow(tty).to receive(:spinning?).and_return(true)
      spinner.stop
      expect(tty).to have_received(:stop)
    end

    it 'stops existing spinner before starting a new one' do
      tty = instance_double(TTY::Spinner, auto_spin: nil, spinning?: true, stop: nil)
      allow(TTY::Spinner).to receive(:new).and_return(tty)

      spinner.start
      spinner.start # should stop the first before starting again

      expect(tty).to have_received(:stop).at_least(:once)
      expect(tty).to have_received(:auto_spin).twice
    end
  end
end
