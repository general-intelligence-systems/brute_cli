# frozen_string_literal: true

RSpec.describe BruteCLI::REPL do
  let(:repl) { build_repl }

  describe '#print_tool_result' do
    it 'prints icon, badge, and summary for any tool' do
      tool = { name: 'read', args: { 'file_path' => 'test.rb' } }
      result = { content: 'file contents' }

      output = capture_stdout { invoke_private(repl, :print_tool_result, tool, result) }

      expect(output).to include('read')
      expect(output).to include('test.rb')
    end

    it 'uses GEAR emoji for unknown tools' do
      tool = { name: 'unknown_tool', args: {} }
      result = { success: true }

      output = capture_stdout { invoke_private(repl, :print_tool_result, tool, result) }

      expect(output).to include(BruteCLI::Emoji::GEAR)
    end

    it 'prints FAILED for error result' do
      tool = { name: 'shell', args: { 'command' => 'badcmd' } }
      result = { error: 'Command not found', message: 'badcmd: not found' }

      output = capture_stdout { invoke_private(repl, :print_tool_result, tool, result) }

      expect(output).to include('FAILED')
      expect(output).to include('badcmd: not found')
    end

    it 'does not print OK' do
      tool = { name: 'write', args: { 'file_path' => 'test.rb' } }
      result = { success: true }

      output = capture_stdout { invoke_private(repl, :print_tool_result, tool, result) }

      expect(output).not_to include('OK')
    end

    it 'includes diff when present' do
      tool = { name: 'patch', args: {} }
      result = { diff: "+ added line\n- removed line\n" }

      output = capture_stdout { invoke_private(repl, :print_tool_result, tool, result) }

      expect(output).to include('added line')
      expect(output).to include('removed line')
    end

    it 'includes stdout when present' do
      tool = { name: 'shell', args: { 'command' => 'echo hello' } }
      result = { stdout: "hello\nworld\n" }

      output = capture_stdout { invoke_private(repl, :print_tool_result, tool, result) }

      expect(output).to include('hello')
    end

    it 'truncates stdout to 15 lines with ellipsis' do
      tool = { name: 'shell', args: {} }
      result = { stdout: (1..20).map { |i| "line #{i}\n" }.join }

      output = capture_stdout { invoke_private(repl, :print_tool_result, tool, result) }

      expect(output).to include('line 1')
      expect(output).to include('line 15')
      expect(output).to include('truncated')
      expect(output).not_to include('line 16')
    end

    it 'truncates long error messages' do
      tool = { name: 'shell', args: {} }
      long_message = 'a' * 100
      result = { error: long_message }

      output = capture_stdout { invoke_private(repl, :print_tool_result, tool, result) }

      expect(output).to include('a' * 70)
      expect(output).to include('...')
    end

    it 'renders todo list from todo_write args' do
      tool = {
        name: 'todo_write',
        args: {
          'todos' => [
            { 'id' => '1', 'content' => 'Fix the bug', 'status' => 'completed' },
            { 'id' => '2', 'content' => 'Write tests', 'status' => 'pending' },
            { 'id' => '3', 'content' => 'Deploy', 'status' => 'in_progress' },
          ]
        }
      }
      result = { success: true, count: 3 }

      output = capture_stdout { invoke_private(repl, :print_tool_result, tool, result) }

      expect(output).to include(BruteCLI::Emoji::CHECK)
      expect(output).to include('Fix the bug')
      expect(output).to include(BruteCLI::Emoji::SQUARE)
      expect(output).to include('Write tests')
      expect(output).to include(BruteCLI::Emoji::ARROWS)
      expect(output).to include('Deploy')
    end

    it 'renders todo list from todo_read result' do
      tool = { name: 'todo_read', args: {} }
      result = {
        todos: [
          { 'id' => '1', 'content' => 'Task A', 'status' => 'completed' },
          { 'id' => '2', 'content' => 'Task B', 'status' => 'cancelled' },
        ]
      }

      output = capture_stdout { invoke_private(repl, :print_tool_result, tool, result) }

      expect(output).to include(BruteCLI::Emoji::CHECK)
      expect(output).to include('Task A')
      expect(output).to include(BruteCLI::Emoji::CROSS)
      expect(output).to include('Task B')
    end
  end

  describe '#format_todos' do
    it 'formats each todo with status emoji' do
      todos = [
        { 'id' => '1', 'content' => 'Pending task', 'status' => 'pending' },
        { 'id' => '2', 'content' => 'In progress', 'status' => 'in_progress' },
        { 'id' => '3', 'content' => 'Done', 'status' => 'completed' },
        { 'id' => '4', 'content' => 'Nope', 'status' => 'cancelled' },
      ]

      lines = invoke_private(repl, :format_todos, todos)

      expect(lines.size).to eq(4)
      expect(lines[0]).to include(BruteCLI::Emoji::SQUARE)
      expect(lines[0]).to include('Pending task')
      expect(lines[1]).to include(BruteCLI::Emoji::ARROWS)
      expect(lines[1]).to include('In progress')
      expect(lines[2]).to include(BruteCLI::Emoji::CHECK)
      expect(lines[2]).to include('Done')
      expect(lines[3]).to include(BruteCLI::Emoji::CROSS)
      expect(lines[3]).to include('Nope')
    end

    it 'handles symbol keys' do
      todos = [
        { id: '1', content: 'Symbol keys', status: 'pending' },
      ]

      lines = invoke_private(repl, :format_todos, todos)

      expect(lines.first).to include('Symbol keys')
    end

    it 'falls back to square emoji for unknown status' do
      todos = [
        { 'id' => '1', 'content' => 'Weird', 'status' => 'banana' },
      ]

      lines = invoke_private(repl, :format_todos, todos)

      expect(lines.first).to include(BruteCLI::Emoji::SQUARE)
    end
  end

  describe '#extract_todos' do
    it 'returns todos from todo_write args' do
      items = [{ 'id' => '1', 'content' => 'X', 'status' => 'pending' }]
      tool = { name: 'todo_write', args: { 'todos' => items } }
      result = { success: true }

      expect(invoke_private(repl, :extract_todos, tool, result)).to eq(items)
    end

    it 'returns todos from todo_read result' do
      items = [{ 'id' => '1', 'content' => 'X', 'status' => 'pending' }]
      tool = { name: 'todo_read', args: {} }
      result = { todos: items }

      expect(invoke_private(repl, :extract_todos, tool, result)).to eq(items)
    end

    it 'returns nil for other tools' do
      tool = { name: 'read', args: {} }
      result = { content: 'data' }

      expect(invoke_private(repl, :extract_todos, tool, result)).to be_nil
    end
  end

  describe '#flush_content' do
    it 'flushes partial content from the streamer' do
      # Populate content_buf and streamer via the normal path
      repl.instance_variable_set(:@content_buf, +'Hello world')
      streamer = repl.instance_variable_get(:@streamer)
      streamer << 'Hello world'

      output = capture_stdout { invoke_private(repl, :flush_content) }
      expect(output.gsub(/\e\[[0-9;]*m/, '')).to include('Hello world')
    end

    it 'clears the buffer after flushing' do
      repl.instance_variable_set(:@content_buf, +'Hello world')
      streamer = repl.instance_variable_get(:@streamer)
      streamer << 'Hello world'

      capture_stdout { invoke_private(repl, :flush_content) }
      expect(repl.instance_variable_get(:@content_buf)).to eq('')
    end

    it 'does nothing when buffer is empty' do
      repl.instance_variable_set(:@content_buf, '')
      output = capture_stdout { invoke_private(repl, :flush_content) }
      expect(output).to be_empty
    end

    it 'does nothing when buffer is whitespace only' do
      repl.instance_variable_set(:@content_buf, +'   
	  ')
      output = capture_stdout { invoke_private(repl, :flush_content) }
      expect(output).to be_empty
    end
  end

  describe '#render_markdown' do
    it 'renders text through BruteCLI::Bat.markdown_mode' do
      text = '# Hello'
      result = invoke_private(repl, :render_markdown, text)
      expect(result).to include('Hello')
    end

    it 'delegates to Bat.markdown_mode with width' do
      expect(BruteCLI::Bat).to receive(:markdown_mode).with('hello', width: anything).and_return('hello')
      invoke_private(repl, :render_markdown, '  hello  ')
    end
  end
end
