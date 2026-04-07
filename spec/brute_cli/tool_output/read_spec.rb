# frozen_string_literal: true

RSpec.describe BruteCLI::ToolOutput::Read do
  def build_output(args: {}, result: nil)
    call = BruteCLI::Phase::ToolCall.new(name: 'read', arguments: args)
    call.result = result if result
    described_class.new(call, width: 80).to_s
  end

  it 'uses the EYES emoji' do
    expect(described_class::ICON).to eq(BruteCLI::Emoji::EYES)
  end

  it 'shows file_path in summary' do
    output = build_output(args: { 'file_path' => 'test.rb' }, result: { content: 'file contents' })
    expect(output).to include('read')
    expect(output).to include('test.rb')
  end
end
