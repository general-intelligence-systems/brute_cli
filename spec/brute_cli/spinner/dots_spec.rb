# frozen_string_literal: true

RSpec.describe BruteCLI::Spinner::Dots do
  subject(:spinner) { described_class.new }

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

    it 'uses the default TTY::Spinner (no custom frames)' do
      tty = instance_double(TTY::Spinner, auto_spin: nil, spinning?: false, stop: nil)
      allow(TTY::Spinner).to receive(:new).and_return(tty)

      spinner.start

      expect(TTY::Spinner).to have_received(:new).with(output: $stdout, clear: true)
    end
  end
end
