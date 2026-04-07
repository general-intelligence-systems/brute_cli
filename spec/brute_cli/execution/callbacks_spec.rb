# frozen_string_literal: true

RSpec.describe BruteCLI::Execution do
  let(:execution) { build_execution }
  let(:spinner) { instance_double(BruteCLI::Spinner::Base, spinning?: true, stop: nil, start: nil) }

  before do
    execution.instance_variable_set(:@spinner, spinner)
  end

  describe '#on_content' do
    it 'stops the spinner' do
      expect(spinner).to receive(:stop)
      invoke_private(execution, :on_content, 'new text')
    end

    it 'creates a ContentPhase and appends text' do
      invoke_private(execution, :on_content, 'hello ')
      invoke_private(execution, :on_content, 'world')
      phase = execution.instance_variable_get(:@current_phase)
      expect(phase).to be_a(BruteCLI::Phase::ContentPhase)
      expect(phase.buf).to eq('hello world')
    end

    it 'streams text to the streamer' do
      streamer = execution.instance_variable_get(:@streamer)
      expect(streamer).to receive(:<<).with('hello')
      invoke_private(execution, :on_content, 'hello')
    end

    it 'reuses existing ContentPhase across multiple calls' do
      invoke_private(execution, :on_content, 'a')
      phase1 = execution.instance_variable_get(:@current_phase)
      invoke_private(execution, :on_content, 'b')
      phase2 = execution.instance_variable_get(:@current_phase)
      expect(phase1).to equal(phase2)
    end
  end

  describe '#on_reasoning' do
    it 'is a no-op' do
      expect { invoke_private(execution, :on_reasoning, 'reasoning text') }.not_to raise_error
    end
  end

  describe '#on_tool_call_start' do
    before do
      allow(spinner).to receive(:stop)
      allow(spinner).to receive(:start)
    end

    it 'stops the spinner' do
      expect(spinner).to receive(:stop)
      invoke_private(execution, :on_tool_call_start, [{ name: 'read', arguments: {} }])
    end

    it 'creates a ToolPhase with the full batch' do
      calls = [
        { name: 'read', arguments: { 'file_path' => 'a.rb' } },
        { name: 'write', arguments: { 'file_path' => 'b.rb' } },
      ]
      invoke_private(execution, :on_tool_call_start, calls)
      phase = execution.instance_variable_get(:@current_phase)
      expect(phase).to be_a(BruteCLI::Phase::ToolPhase)
      expect(phase.tool_calls.size).to eq(2)
      expect(phase.tool_calls.map(&:name)).to eq(%w[read write])
    end

    it 'renders all tool call headers via puts' do
      calls = [{ name: 'read', arguments: { 'file_path' => 'test.rb' } }]
      output = capture_stdout { invoke_private(execution, :on_tool_call_start, calls) }
      expect(output).to include('read')
      expect(output).to include('test.rb')
    end

    it 'restarts the spinner' do
      expect(spinner).to receive(:start)
      invoke_private(execution, :on_tool_call_start, [{ name: 'read', arguments: {} }])
    end
  end

  describe '#on_tool_result' do
    before do
      allow(spinner).to receive(:stop)
      allow(spinner).to receive(:start)
      # Set up a ToolPhase with 2 calls
      calls = [
        { name: 'read', arguments: { 'file_path' => 'a.rb' } },
        { name: 'write', arguments: { 'file_path' => 'b.rb' } },
      ]
      execution.instance_variable_set(
        :@current_phase,
        BruteCLI::Phase::ToolPhase.new(calls)
      )
    end

    it 'stops the spinner' do
      expect(spinner).to receive(:stop)
      invoke_private(execution, :on_tool_result, 'read', { content: 'data' })
    end

    it 'resolves the matching tool call' do
      invoke_private(execution, :on_tool_result, 'read', { content: 'data' })
      phase = execution.instance_variable_get(:@current_phase)
      read_call = phase.tool_calls.find { |c| c.name == 'read' }
      expect(read_call.resolved?).to be true
      expect(read_call.result).to eq({ content: 'data' })
    end

    it 're-renders all tool calls' do
      output = capture_stdout { invoke_private(execution, :on_tool_result, 'read', { content: 'data' }) }
      # Both tool calls should appear in the re-rendered output
      expect(output).to include('read')
      expect(output).to include('write')
    end

    it 'restarts spinner after resolving' do
      expect(spinner).to receive(:start)
      invoke_private(execution, :on_tool_result, 'read', { content: 'data' })
    end

    it 'restarts spinner even when phase is finished (waiting for next LLM turn)' do
      invoke_private(execution, :on_tool_result, 'read', { content: 'data' })
      expect(spinner).to receive(:start)
      invoke_private(execution, :on_tool_result, 'write', { success: true })
    end
  end

  describe 'ToolOutput integration' do
    it 'returns correct ToolOutput types for ToolCall objects' do
      read_call = BruteCLI::Phase::ToolCall.new(name: 'read', arguments: {})
      expect(BruteCLI::ToolOutput.for(read_call)).to be_a(BruteCLI::ToolOutput::Read)

      shell_call = BruteCLI::Phase::ToolCall.new(name: 'shell', arguments: {})
      expect(BruteCLI::ToolOutput.for(shell_call)).to be_a(BruteCLI::ToolOutput::Shell)

      write_call = BruteCLI::Phase::ToolCall.new(name: 'write', arguments: {})
      expect(BruteCLI::ToolOutput.for(write_call)).to be_a(BruteCLI::ToolOutput::Write)
    end
  end

  describe '@last_output separator deduplication' do
    before do
      allow(spinner).to receive(:stop)
      allow(spinner).to receive(:start)
    end

    it 'skips separator in start_spinner when last output is already a separator' do
      execution.instance_variable_set(:@last_output, :separator)

      output = capture_stdout { invoke_private(execution, :start_spinner) }
      sep_line = BruteCLI::BufferOutput::Separator.new(width: 80).to_s
      lines = output.lines.map(&:strip).select { |l| l == sep_line.strip }
      expect(lines.size).to eq(0)
    end

    it 'prints separator in start_spinner when last output was content' do
      execution.instance_variable_set(:@last_output, :content)

      output = capture_stdout { invoke_private(execution, :start_spinner) }
      expect(output).to include("\u2500")
    end

    it 'prints separator in start_spinner when last output was tool' do
      execution.instance_variable_set(:@last_output, :tool)

      output = capture_stdout { invoke_private(execution, :start_spinner) }
      expect(output).to include("\u2500")
    end

    it 'sets last_output to :content on on_content' do
      invoke_private(execution, :on_content, 'hello')
      expect(execution.instance_variable_get(:@last_output)).to eq(:content)
    end

    it 'sets last_output to :separator after start_spinner' do
      execution.instance_variable_set(:@last_output, :content)
      capture_stdout { invoke_private(execution, :start_spinner) }
      expect(execution.instance_variable_get(:@last_output)).to eq(:separator)
    end

    it 'does not set last_output to :content when flush_content has blank buffer' do
      # Set up an empty ContentPhase
      streamer = execution.instance_variable_get(:@streamer)
      execution.instance_variable_set(:@current_phase, BruteCLI::Phase::ContentPhase.new(streamer))
      execution.instance_variable_set(:@last_output, :separator)
      invoke_private(execution, :flush_content)
      expect(execution.instance_variable_get(:@last_output)).to eq(:separator)
    end
  end
end
