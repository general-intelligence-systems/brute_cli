# frozen_string_literal: true

RSpec.describe BruteCLI::ToolOutput::Write do
  def build_output(args: {}, result: nil)
    call = BruteCLI::Phase::ToolCall.new(name: 'write', arguments: args)
    call.result = result if result
    described_class.new(call, width: 80).to_s
  end

  it 'uses the WRITING emoji' do
    expect(described_class::ICON).to eq(BruteCLI::Emoji::WRITING)
  end

  it 'shows file_path in summary' do
    output = build_output(args: { 'file_path' => 'test.rb' }, result: { success: true })
    expect(output).to include('test.rb')
  end

  it 'does not print OK' do
    output = build_output(args: { 'file_path' => 'test.rb' }, result: { success: true })
    expect(output).not_to include('OK')
  end

  it 'includes diff when present' do
    output = build_output(result: { diff: "+ new content\n" })
    expect(output).to include('new content')
  end
end
