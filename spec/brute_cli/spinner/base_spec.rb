# frozen_string_literal: true

RSpec.describe BruteCLI::Spinner::Base do
  subject(:spinner) { described_class.new }

  describe '#start' do
    it 'raises NotImplementedError' do
      expect { spinner.start }.to raise_error(NotImplementedError)
    end
  end

  describe '#stop' do
    it 'raises NotImplementedError' do
      expect { spinner.stop }.to raise_error(NotImplementedError)
    end
  end

  describe '#spinning?' do
    it 'raises NotImplementedError' do
      expect { spinner.spinning? }.to raise_error(NotImplementedError)
    end
  end
end
