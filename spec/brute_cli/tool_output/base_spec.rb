# frozen_string_literal: true

RSpec.describe BruteCLI::ToolOutput::Base do
  def build_call(name:, arguments: {}, result: nil)
    call = BruteCLI::Phase::ToolCall.new(name: name, arguments: arguments)
    call.result = result if result
    call
  end

  describe '#to_s' do
    it 'includes the GEAR icon for unknown tools' do
      call = build_call(name: 'unknown_tool', result: { success: true })
      output = described_class.new(call, width: 80).to_s
      expect(output).to include(BruteCLI::Emoji::GEAR)
    end

    it 'includes the tool name as a badge' do
      call = build_call(name: 'unknown_tool', result: { success: true })
      output = described_class.new(call, width: 80).to_s
      expect(output).to include('unknown_tool')
    end

    it 'includes FAILED for error results' do
      call = build_call(name: 'something', result: { error: 'Command not found', message: 'badcmd: not found' })
      output = described_class.new(call, width: 80).to_s
      expect(output).to include('FAILED')
      expect(output).to include('badcmd: not found')
    end

    it 'truncates long error messages' do
      long_message = 'a' * 100
      call = build_call(name: 'something', result: { error: long_message })
      output = described_class.new(call, width: 80).to_s
      expect(output).to include('a' * 70)
      expect(output).to include('...')
    end

    it 'does not include FAILED for success results' do
      call = build_call(name: 'something', result: { success: true })
      output = described_class.new(call, width: 80).to_s
      expect(output).not_to include('FAILED')
    end

    it 'returns only header line when call is pending' do
      call = build_call(name: 'something')
      output = described_class.new(call, width: 80).to_s
      expect(output).to include('something')
      expect(output).not_to include('FAILED')
    end
  end
end
