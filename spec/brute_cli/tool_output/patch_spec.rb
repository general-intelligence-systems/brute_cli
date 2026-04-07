# frozen_string_literal: true

RSpec.describe BruteCLI::ToolOutput::Patch do
  def build_output(args: {}, result: nil)
    call = BruteCLI::Phase::ToolCall.new(name: 'patch', arguments: args)
    call.result = result if result
    described_class.new(call, width: 80).to_s
  end

  it 'uses the HAMMER emoji' do
    expect(described_class::ICON).to eq(BruteCLI::Emoji::HAMMER)
  end

  it 'shows file_path in summary' do
    output = build_output(args: { 'file_path' => 'app/models/user.rb' }, result: { success: true })
    expect(output).to include('app/models/user.rb')
  end

  it 'includes diff when present' do
    output = build_output(result: { diff: "+ added line\n- removed line\n" })
    expect(output).to include('added line')
    expect(output).to include('removed line')
  end
end
