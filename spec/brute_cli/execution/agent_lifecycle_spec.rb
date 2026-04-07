# frozen_string_literal: true

RSpec.describe BruteCLI::Execution do
  let(:execution) { build_execution(cwd: '/tmp/test') }
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
      execution.ensure_agent!
    end

    it 'creates a new agent with correct parameters' do
      expect(Brute).to receive(:agent).with(
        hash_including(
          cwd: '/tmp/test',
          model: nil,
          agent_name: 'build',
          session: session,
        )
      ).and_return(agent)
      execution.ensure_agent!
    end

    it 'is idempotent - does not recreate agent on second call' do
      execution.ensure_agent!
      expect(Brute).not_to receive(:agent)
      execution.ensure_agent!
    end

    context 'with session_id' do
      let(:execution) { build_execution(cwd: '/tmp/test', session_id: 'abc123') }

      it 'creates session with the given id' do
        expect(Brute::Session).to receive(:new).with(id: 'abc123').and_return(session)
        execution.ensure_agent!
      end

      it 'restores the session' do
        expect(session).to receive(:restore).with(agent.context)
        execution.ensure_agent!
      end
    end
  end

  describe '#execute' do
    before do
      execution.instance_variable_set(:@agent, agent)
      execution.instance_variable_set(:@provider_name, 'anthropic')
      execution.instance_variable_set(:@model_name, 'claude-3.5-sonnet')
    end

    it 'resets current phase' do
      execution.instance_variable_set(:@current_phase, BruteCLI::Phase::ContentPhase.new(
        execution.instance_variable_get(:@streamer)
      ))
      allow(agent).to receive(:run)
      invoke_private(execution, :execute, 'prompt')
      expect(execution.instance_variable_get(:@current_phase)).to be_nil
    end

    it 'calls agent.run with the prompt' do
      expect(agent).to receive(:run).with('test prompt')
      invoke_private(execution, :execute, 'test prompt')
    end

    it 'handles Interrupt gracefully' do
      allow(agent).to receive(:run).and_raise(Interrupt)
      output = capture_stdout { invoke_private(execution, :execute, 'prompt') }
      expect(output).to include('Aborted')
    end

    it 'prints stats after Interrupt' do
      allow(agent).to receive(:run).and_raise(Interrupt)
      output = capture_stdout { invoke_private(execution, :execute, 'prompt') }
      expect(output).to include('tokens')
    end

    it 'handles StandardError and prints error' do
      error = StandardError.new('Something went wrong')
      allow(agent).to receive(:run).and_raise(error)
      output = capture_stdout { invoke_private(execution, :execute, 'prompt') }
      expect(output).to include('ERROR')
      expect(output).to include('Something went wrong')
    end

    it 'prints stats after error' do
      allow(agent).to receive(:run).and_raise(StandardError, 'fail')
      output = capture_stdout { invoke_private(execution, :execute, 'prompt') }
      expect(output).to include('tokens')
    end
  end

  describe '#run' do
    it 'ensures agent and executes prompt' do
      expect(execution).to receive(:ensure_agent!)
      expect(execution).to receive(:execute).with('test prompt')
      execution.run('test prompt')
    end
  end

  describe '#print_error' do
    it 'prints styled error message' do
      error = StandardError.new('Test error')
      output = capture_stdout { invoke_private(execution, :print_error, error) }
      expect(output).to include('ERROR')
      expect(output).to include('Test error')
    end

  end



  describe '#detect_width' do
    it 'delegates to TTY::Screen.width' do
      allow(TTY::Screen).to receive(:width).and_return(120)
      expect(execution.detect_width).to eq(120)
    end

    it 'returns 80 as default when no terminal is available' do
      allow(TTY::Screen).to receive(:width).and_return(80)
      expect(execution.detect_width).to eq(80)
    end
  end
end
