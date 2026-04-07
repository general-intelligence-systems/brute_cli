# frozen_string_literal: true

RSpec.describe BruteCLI::REPL do
  let(:repl) { build_repl(cwd: '/tmp/test') }

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

  describe '#cycle_agent' do
    let(:execution) { repl.instance_variable_get(:@execution) }

    before do
      # Suppress terminal escape sequences
      allow($stdout).to receive(:print)
      allow($stdout).to receive(:flush)
    end

    it 'switches from build to plan' do
      invoke_private(repl, :cycle_agent, :forward)
      expect(execution.current_agent).to eq('plan')
    end

    it 'cycles backward from build to nix (last agent)' do
      invoke_private(repl, :cycle_agent, :backward)
      expect(execution.current_agent).to eq('nix')
    end

    it 'wraps around through all agents back to build' do
      agents = BruteCLI::Execution::AGENTS
      agents.size.times { invoke_private(repl, :cycle_agent, :forward) }
      expect(execution.current_agent).to eq('build')
    end

    it 'resets the agent on each cycle' do
      allow(Brute::Session).to receive(:new).and_return(instance_double(Brute::Session, restore: nil))
      allow(Brute).to receive(:agent).and_return(
        instance_double("agent", run: nil, env: {}, context: double("context"))
      )
      execution.ensure_agent!
      expect(execution.agent).not_to be_nil

      invoke_private(repl, :cycle_agent, :forward)
      expect(execution.agent).to be_nil
    end
  end
end
