# frozen_string_literal: true

RSpec.describe BruteCLI::Execution do
  let(:execution) { build_execution }

  describe '#render_tool_phase' do
    it 'renders all tool calls via ToolOutput.for' do
      calls = [
        { name: 'read', arguments: { 'file_path' => 'test.rb' } },
        { name: 'shell', arguments: { 'command' => 'ls' } },
      ]
      execution.instance_variable_set(:@current_phase, BruteCLI::Phase::ToolPhase.new(calls))

      output = capture_stdout { invoke_private(execution, :render_tool_phase) }
      expect(output).to include('read')
      expect(output).to include('test.rb')
      expect(output).to include('shell')
      expect(output).to include('ls')
    end

    it 'falls back to Base for unknown tools' do
      calls = [{ name: 'unknown_tool', arguments: {} }]
      execution.instance_variable_set(:@current_phase, BruteCLI::Phase::ToolPhase.new(calls))

      output = capture_stdout { invoke_private(execution, :render_tool_phase) }
      expect(output).to include(BruteCLI::Emoji::GEAR)
    end

    it 'renders resolved calls with body and pending calls as header only' do
      phase = BruteCLI::Phase::ToolPhase.new([
        { name: 'shell', arguments: { 'command' => 'echo hi' } },
        { name: 'read', arguments: { 'file_path' => 'foo.rb' } },
      ])
      phase.resolve('shell', { stdout: "hi\n" })
      execution.instance_variable_set(:@current_phase, phase)

      output = capture_stdout { invoke_private(execution, :render_tool_phase) }
      # Shell should have its body (stdout)
      expect(output).to include('hi')
      # Read should appear as header
      expect(output).to include('foo.rb')
    end
  end

  describe '#flush_content' do
    it 'flushes partial content from the streamer' do
      streamer = execution.instance_variable_get(:@streamer)
      phase = BruteCLI::Phase::ContentPhase.new(streamer)
      phase.append('Hello world')
      execution.instance_variable_set(:@current_phase, phase)

      output = capture_stdout { invoke_private(execution, :flush_content) }
      expect(output.gsub(/\e\[[0-9;]*m/, '')).to include('Hello world')
    end

    it 'clears the buffer after flushing' do
      streamer = execution.instance_variable_get(:@streamer)
      phase = BruteCLI::Phase::ContentPhase.new(streamer)
      phase.append('Hello world')
      execution.instance_variable_set(:@current_phase, phase)

      capture_stdout { invoke_private(execution, :flush_content) }
      expect(phase.buf).to eq('')
    end

    it 'does nothing when there is no content phase' do
      execution.instance_variable_set(:@current_phase, nil)
      output = capture_stdout { invoke_private(execution, :flush_content) }
      expect(output).to be_empty
    end

    it 'does nothing when buffer is whitespace only' do
      streamer = execution.instance_variable_get(:@streamer)
      phase = BruteCLI::Phase::ContentPhase.new(streamer)
      phase.append("   \n\t  ")
      execution.instance_variable_set(:@current_phase, phase)

      output = capture_stdout { invoke_private(execution, :flush_content) }
      expect(output).to be_empty
    end
  end

  describe '#render_markdown' do
    it 'renders text through BruteCLI::Bat.markdown_mode' do
      text = '# Hello'
      result = invoke_private(execution, :render_markdown, text)
      expect(result).to include('Hello')
    end

    it 'delegates to Bat.markdown_mode with width' do
      expect(BruteCLI::Bat).to receive(:markdown_mode).with('hello', width: anything).and_return('hello')
      invoke_private(execution, :render_markdown, '  hello  ')
    end
  end
end
