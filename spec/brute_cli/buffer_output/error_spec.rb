# frozen_string_literal: true

RSpec.describe BruteCLI::BufferOutput::Error do
  describe '#to_s' do
    it 'includes the ERROR badge' do
      err = StandardError.new('Something went wrong')
      result = described_class.new(err).to_s
      expect(result).to include('ERROR')
    end

    it 'includes the error message' do
      err = StandardError.new('Something went wrong')
      result = described_class.new(err).to_s
      expect(result).to include('Something went wrong')
    end

    it 'includes the cross emoji' do
      err = StandardError.new('fail')
      result = described_class.new(err).to_s
      expect(result).to include(BruteCLI::Emoji::CROSS)
    end

    it 'parses JSON error messages' do
      err = StandardError.new('{"error":"bad request","code":400}')
      result = described_class.new(err).to_s
      expect(result).to include('bad request')
      expect(result).to include('400')
    end

    it 'falls back to raw message for non-JSON' do
      err = StandardError.new('plain text error')
      result = described_class.new(err).to_s
      expect(result).to include('plain text error')
    end

    it 'works with puts' do
      err = StandardError.new('test')
      output = capture_stdout { puts described_class.new(err) }
      expect(output).to include('ERROR')
      expect(output).to include('test')
    end
  end
end
