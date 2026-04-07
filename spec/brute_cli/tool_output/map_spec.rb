# frozen_string_literal: true

RSpec.describe BruteCLI::ToolOutput do
  def build_call(name)
    BruteCLI::Phase::ToolCall.new(name: name, arguments: {})
  end

  describe '.for' do
    {
      "read"       => BruteCLI::ToolOutput::Read,
      "write"      => BruteCLI::ToolOutput::Write,
      "patch"      => BruteCLI::ToolOutput::Patch,
      "shell"      => BruteCLI::ToolOutput::Shell,
      "fs_search"  => BruteCLI::ToolOutput::FsSearch,
      "fetch"      => BruteCLI::ToolOutput::Fetch,
      "remove"     => BruteCLI::ToolOutput::Remove,
      "undo"       => BruteCLI::ToolOutput::Undo,
      "delegate"   => BruteCLI::ToolOutput::Delegate,
      "question"   => BruteCLI::ToolOutput::Question,
      "todo_read"  => BruteCLI::ToolOutput::TodoRead,
      "todo_write" => BruteCLI::ToolOutput::TodoWrite,
    }.each do |name, klass|
      it "maps '#{name}' to #{klass}" do
        result = described_class.for(build_call(name))
        expect(result).to be_a(klass)
      end
    end

    it 'falls back to Base for unknown tools' do
      result = described_class.for(build_call('unknown'))
      expect(result).to be_a(BruteCLI::ToolOutput::Base)
    end
  end

  describe 'MAP' do
    it 'is frozen' do
      expect(described_class::MAP).to be_frozen
    end

    it 'contains 12 entries' do
      expect(described_class::MAP.size).to eq(12)
    end
  end
end
