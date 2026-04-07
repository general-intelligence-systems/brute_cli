# frozen_string_literal: true

RSpec.describe BruteCLI::ToolOutput::Shell do
  def build_output(args: {}, result: nil)
    call = BruteCLI::Phase::ToolCall.new(name: 'shell', arguments: args)
    call.result = result if result
    described_class.new(call, width: 80).to_s
  end

  it 'uses the COMPUTER emoji' do
    expect(described_class::ICON).to eq(BruteCLI::Emoji::COMPUTER)
  end

  it 'shows command in summary' do
    output = build_output(args: { 'command' => 'echo hello' }, result: { stdout: '' })
    expect(output).to include('echo hello')
  end

  it 'truncates command summary to 60 chars' do
    long_cmd = 'x' * 100
    output = build_output(args: { 'command' => long_cmd }, result: { stdout: '' })
    # Should contain at most 61 chars of the command (0..60)
    expect(output).to include('x' * 61)
    expect(output).not_to include('x' * 62)
  end

  it 'renders stdout lines' do
    output = build_output(args: { 'command' => 'echo hello' }, result: { stdout: "hello\nworld\n" })
    expect(output).to include('hello')
    expect(output).to include('world')
  end

  it 'truncates stdout to 15 lines' do
    output = build_output(args: {}, result: { stdout: (1..20).map { |i| "line #{i}\n" }.join })
    expect(output).to include('line 1')
    expect(output).to include('line 15')
    expect(output).to include('truncated')
    expect(output).not_to include('line 16')
  end

  it 'prints FAILED for error result' do
    output = build_output(
      args: { 'command' => 'badcmd' },
      result: { error: 'Command not found', message: 'badcmd: not found' }
    )
    expect(output).to include('FAILED')
    expect(output).to include('badcmd: not found')
  end
end
