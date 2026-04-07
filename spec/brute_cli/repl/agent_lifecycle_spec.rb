# frozen_string_literal: true

RSpec.describe BruteCLI::REPL do
  let(:repl) { build_repl(cwd: '/tmp/test') }
  let(:session) { instance_double(Brute::Session, restore: nil) }
  let(:agent) do
    instance_double(
      'agent',
      run: nil,
      env: { metadata: { tokens: {}, timing: {}, tool_calls: 5 } },
      context: double('context')
    )
  end

  before do
    allow(Brute::Session).to receive(:new).and_return(session)
    allow(Brute).to receive(:agent).and_return(agent)
  end

  describe '#ensure_agent!' do
    it 'creates a new session' do
      expect(Brute::Session).to receive(:new).with(id: nil).and_return(session)
      invoke_private(repl, :ensure_agent!)
    end

    it 'creates a new agent with correct parameters' do
      expect(Brute).to receive(:agent).with(
        cwd: '/tmp/test',
        model: nil,
        session: session,
        logger: instance_of(Logger),
        on_content: anything,
        on_reasoning: anything,
        on_tool_call: anything,
        on_tool_result: anything,
        on_question: anything
      ).and_return(agent)
      invoke_private(repl, :ensure_agent!)
    end

    it 'is idempotent - does not recreate agent on second call' do
      invoke_private(repl, :ensure_agent!)
      expect(Brute).not_to receive(:agent)
      invoke_private(repl, :ensure_agent!)
    end

    context 'with session_id' do
      let(:repl) { build_repl(cwd: '/tmp/test', session_id: 'abc123') }

      it 'creates session with the given id' do
        expect(Brute::Session).to receive(:new).with(id: 'abc123').and_return(session)
        invoke_private(repl, :ensure_agent!)
      end

      it 'restores the session' do
        expect(session).to receive(:restore).with(agent.context)
        invoke_private(repl, :ensure_agent!)
      end
    end
  end

  describe '#execute' do
    before do
      repl.instance_variable_set(:@agent, agent)
      repl.instance_variable_set(:@provider_name, 'anthropic')
      repl.instance_variable_set(:@model_name, 'claude-3.5-sonnet')
    end

    it 'clears content buffer' do
      repl.instance_variable_set(:@content_buf, 'old content')
      allow(agent).to receive(:run)
      invoke_private(repl, :execute, 'prompt')
      expect(repl.instance_variable_get(:@content_buf)).to eq('')
    end

    it 'calls agent.run with the prompt' do
      expect(agent).to receive(:run).with('test prompt')
      invoke_private(repl, :execute, 'test prompt')
    end

    it 'handles Interrupt gracefully' do
      allow(agent).to receive(:run).and_raise(Interrupt)
      output = capture_stdout { invoke_private(repl, :execute, 'prompt') }
      expect(output).to include('Aborted')
    end

    it 'prints stats after Interrupt' do
      allow(agent).to receive(:run).and_raise(Interrupt)
      output = capture_stdout { invoke_private(repl, :execute, 'prompt') }
      expect(output).to include('tokens')
    end

    it 'handles StandardError and prints error' do
      error = StandardError.new('Something went wrong')
      allow(agent).to receive(:run).and_raise(error)
      output = capture_stdout { invoke_private(repl, :execute, 'prompt') }
      expect(output).to include('ERROR')
      expect(output).to include('Something went wrong')
    end

    it 'prints stats after error' do
      allow(agent).to receive(:run).and_raise(StandardError, 'fail')
      output = capture_stdout { invoke_private(repl, :execute, 'prompt') }
      expect(output).to include('tokens')
    end
  end

  describe '#run_once' do
    it 'ensures agent and executes prompt' do
      expect(repl).to receive(:ensure_agent!)
      expect(repl).to receive(:execute).with('test prompt')
      repl.run_once('test prompt')
    end
  end

  describe '#print_error' do
    it 'prints styled error message' do
      error = StandardError.new('Test error')
      output = capture_stdout { invoke_private(repl, :print_error, error) }
      expect(output).to include('ERROR')
      expect(output).to include('Test error')
    end

  end

  describe '#separator' do
    it 'returns a string of box-drawing characters' do
      result = invoke_private(repl, :separator)
      expect(result).to include('─')
    end
  end

  describe '#check_dependencies' do
    it 'prints nothing when bat and fzf are available' do
      allow(BruteCLI::Bat).to receive(:available?).and_return(true)
      allow(repl).to receive(:fzf_on_path?).and_return(true)

      stdout = capture_stdout { invoke_private(repl, :check_dependencies) }
      stderr = capture_stderr { invoke_private(repl, :check_dependencies) }

      expect(stdout).to eq('')
      expect(stderr).to eq('')
    end

    it 'prints a styled warning when bat is missing' do
      allow(BruteCLI::Bat).to receive(:available?).and_return(false)
      allow(repl).to receive(:fzf_on_path?).and_return(true)

      stderr = capture_stderr { capture_stdout { invoke_private(repl, :check_dependencies) } }

      expect(stderr).to include('bat not found')
      expect(stderr).to include('diff syntax highlighting')
    end

    it 'prints a styled warning when fzf is missing' do
      allow(BruteCLI::Bat).to receive(:available?).and_return(true)
      allow(repl).to receive(:fzf_on_path?).and_return(false)

      stderr = capture_stderr { capture_stdout { invoke_private(repl, :check_dependencies) } }

      expect(stderr).to include('fzf not found')
      expect(stderr).to include('interactive selection')
    end

    it 'prints warnings for both when both are missing' do
      allow(BruteCLI::Bat).to receive(:available?).and_return(false)
      allow(repl).to receive(:fzf_on_path?).and_return(false)

      stderr = capture_stderr { capture_stdout { invoke_private(repl, :check_dependencies) } }

      expect(stderr).to include('bat not found')
      expect(stderr).to include('fzf not found')
    end
  end

  describe '#detect_width' do
    it 'delegates to TTY::Screen.width' do
      allow(TTY::Screen).to receive(:width).and_return(120)
      expect(invoke_private(repl, :detect_width)).to eq(120)
    end

    it 'returns 80 as default when no terminal is available' do
      allow(TTY::Screen).to receive(:width).and_return(80)
      expect(invoke_private(repl, :detect_width)).to eq(80)
    end
  end
end
