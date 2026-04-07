# frozen_string_literal: true

RSpec.describe BruteCLI::Phase::ToolCall do
  let(:call) { described_class.new(name: "read", arguments: { "file_path" => "foo.rb" }) }

  it 'stores name and arguments' do
    expect(call.name).to eq("read")
    expect(call.arguments).to eq({ "file_path" => "foo.rb" })
  end

  it 'starts with nil result' do
    expect(call.result).to be_nil
  end

  it 'is pending when unresolved' do
    expect(call.pending?).to be true
    expect(call.resolved?).to be false
  end

  it 'is resolved after setting result' do
    call.result = { content: "data" }
    expect(call.resolved?).to be true
    expect(call.pending?).to be false
  end

  it 'defaults arguments to empty hash when nil' do
    call = described_class.new(name: "read", arguments: nil)
    expect(call.arguments).to eq({})
  end
end
