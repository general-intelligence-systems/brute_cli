# frozen_string_literal: true

RSpec.describe BruteCLI::Phase::ToolPhase do
  let(:calls) do
    [
      { name: "read", arguments: { "file_path" => "a.rb" } },
      { name: "write", arguments: { "file_path" => "b.rb" } },
      { name: "read", arguments: { "file_path" => "c.rb" } },
    ]
  end
  let(:phase) { described_class.new(calls) }

  it 'creates ToolCall objects for each call' do
    expect(phase.tool_calls.size).to eq(3)
    expect(phase.tool_calls.map(&:name)).to eq(%w[read write read])
  end

  it 'starts not finished' do
    expect(phase.finished?).to be false
  end

  describe '#resolve' do
    it 'resolves the first unresolved call matching name' do
      call = phase.resolve("read", { content: "data" })
      expect(call.name).to eq("read")
      expect(call.arguments).to eq({ "file_path" => "a.rb" })
      expect(call.resolved?).to be true
    end

    it 'resolves the second matching call on next resolve' do
      phase.resolve("read", { content: "first" })
      call = phase.resolve("read", { content: "second" })
      expect(call.arguments).to eq({ "file_path" => "c.rb" })
      expect(call.result).to eq({ content: "second" })
    end

    it 'returns nil when no unresolved call matches' do
      expect(phase.resolve("unknown", {})).to be_nil
    end
  end

  describe '#finished?' do
    it 'returns true when all calls are resolved' do
      phase.resolve("read", {})
      phase.resolve("write", {})
      phase.resolve("read", {})
      expect(phase.finished?).to be true
    end

    it 'returns false when some calls are still pending' do
      phase.resolve("read", {})
      expect(phase.finished?).to be false
    end
  end
end
