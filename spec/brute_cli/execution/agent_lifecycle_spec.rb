# frozen_string_literal: true

RSpec.describe BruteCLI::Execution do
  let(:execution) { build_execution(cwd: '/tmp/test') }
  let(:agent) do
    instance_double('Brute::Agent', call: nil)
  end
  let(:session) { Brute::Session.new }

  before do
    allow(Brute::Session).to receive(:new).and_return(session)
    allow(Brute::Agent).to receive(:new).and_return(agent)
    allow(FileUtils).to receive(:mkdir_p)
  end

  describe '#ensure_agent!' do
    it 'creates a new session with a path' do
      expect(Brute::Session).to receive(:new).with(hash_including(:path)).and_return(session)
      execution.ensure_agent!
    end

    it 'creates a Brute::Agent' do
      expect(Brute::Agent).to receive(:new).with(
        hash_including(
          provider: anything,
          tools: Brute::Tools::ALL,
        )
      ).and_return(agent)
      execution.ensure_agent!
    end

    it 'is idempotent - does not recreate agent on second call' do
      execution.ensure_agent!
      expect(Brute::Agent).not_to receive(:new)
      execution.ensure_agent!
    end

    context 'with session_id' do
      let(:execution) { build_execution(cwd: '/tmp/test', session_id: 'abc123') }

      it 'creates session with path derived from session id' do
        expected_path = File.join(Dir.home, '.brute', 'sessions', 'abc123', 'session.jsonl')
        expect(Brute::Session).to receive(:new).with(path: expected_path).and_return(session)
        execution.ensure_agent!
      end

      context 'when session file exists' do
        before do
          allow(File).to receive(:exist?).and_call_original
          expected_path = File.join(Dir.home, '.brute', 'sessions', 'abc123', 'session.jsonl')
          allow(File).to receive(:exist?).with(expected_path).and_return(true)
          allow(Brute::Session).to receive(:from_jsonl).and_return(session)
        end

        it 'loads session from JSONL' do
          expect(Brute::Session).to receive(:from_jsonl).and_return(session)
          execution.ensure_agent!
        end
      end
    end
  end

  describe '#execute' do
    before do
      execution.instance_variable_set(:@agent, agent)
      execution.instance_variable_set(:@session, session)
      execution.instance_variable_set(:@provider_name, 'anthropic')
      execution.instance_variable_set(:@model_name, 'claude-3.5-sonnet')
    end

    it 'resets current phase' do
      execution.instance_variable_set(:@current_phase, BruteCLI::Phase::ContentPhase.new(
        execution.instance_variable_get(:@streamer)
      ))
      allow(agent).to receive(:call)
      invoke_private(execution, :execute, 'prompt')
      expect(execution.instance_variable_get(:@current_phase)).to be_nil
    end

    it 'adds user message to session and calls agent' do
      expect(agent).to receive(:call).with(session, hash_including(:events))
      invoke_private(execution, :execute, 'test prompt')
    end

    it 'handles Interrupt gracefully' do
      allow(agent).to receive(:call).and_raise(Interrupt)
      output = capture_stdout { invoke_private(execution, :execute, 'prompt') }
      expect(output).to include('Aborted')
    end

    it 'prints stats after Interrupt' do
      allow(agent).to receive(:call).and_raise(Interrupt)
      output = capture_stdout { invoke_private(execution, :execute, 'prompt') }
      expect(output).to include('tokens')
    end

    it 'handles StandardError and prints error' do
      error = StandardError.new('Something went wrong')
      allow(agent).to receive(:call).and_raise(error)
      output = capture_stdout { invoke_private(execution, :execute, 'prompt') }
      expect(output).to include('ERROR')
      expect(output).to include('Something went wrong')
    end

    it 'prints stats after error' do
      allow(agent).to receive(:call).and_raise(StandardError, 'fail')
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

  describe '.list_sessions' do
    it 'returns empty array when sessions dir does not exist' do
      allow(Dir).to receive(:exist?).and_return(false)
      expect(BruteCLI::Execution.list_sessions).to eq([])
    end

    it 'returns sessions sorted by mtime descending' do
      dir = BruteCLI::Execution::SESSIONS_DIR
      allow(Dir).to receive(:exist?).with(dir).and_return(true)
      allow(Dir).to receive(:glob).and_return([
        "#{dir}/aaa/session.jsonl",
        "#{dir}/bbb/session.jsonl",
      ])
      allow(File).to receive(:mtime).with("#{dir}/aaa/session.jsonl").and_return(Time.new(2024, 1, 1))
      allow(File).to receive(:mtime).with("#{dir}/bbb/session.jsonl").and_return(Time.new(2024, 6, 1))

      sessions = BruteCLI::Execution.list_sessions
      expect(sessions.first[:id]).to eq('bbb')
      expect(sessions.last[:id]).to eq('aaa')
    end
  end
end
