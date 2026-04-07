# frozen_string_literal: true

RSpec.describe BruteCLI do
  describe '.error' do
    it 'outputs styled error to stderr' do
      output = capture_stderr { BruteCLI.error('Something went wrong') }
      expect(output).to include('ERROR')
      expect(output).to include('Something went wrong')
    end
  end

  describe '.warn' do
    it 'outputs styled warning to stderr' do
      output = capture_stderr { BruteCLI.warn('This is a warning') }
      expect(output).to include('warning:')
      expect(output).to include('This is a warning')
    end
  end
end

RSpec.describe BruteCli do
  describe '::VERSION' do
    it 'is a non-nil string' do
      expect(BruteCli::VERSION).to be_a(String)
      expect(BruteCli::VERSION).not_to be_empty
    end

    it 'follows semver format (major.minor.patch)' do
      expect(BruteCli::VERSION).to match(/^\d+\.\d+\.\d+$/)
    end
  end
end
