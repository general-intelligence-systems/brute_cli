# frozen_string_literal: true

RSpec.describe BruteCLI::Spinner::PuffPuffPass do
  subject(:spinner) { described_class.new }

  describe 'FRAMES' do
    let(:smoke) { BruteCLI::Emoji::SMOKE }

    it 'has 4 frames of increasing smoke emojis' do
      expected = (1..4).map { |n| (smoke + " ") * n }
      expect(described_class::FRAMES).to eq(expected)
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

      spinner.stop
      expect(tty).to have_received(:stop)
    end

    it 'passes smoke frames to TTY::Spinner' do
      tty = instance_double(TTY::Spinner, auto_spin: nil, spinning?: false, stop: nil)
      allow(TTY::Spinner).to receive(:new).and_return(tty)

      spinner.start

      expect(TTY::Spinner).to have_received(:new).with(
        ":spinner",
        frames: described_class::FRAMES,
        interval: 200,
        output: $stdout,
        clear: true,
      )
    end
  end
end
