# frozen_string_literal: true

RSpec.describe BruteCLI::REPL, "mode switching" do
  let(:repl) { build_repl(cwd: "/tmp/test") }
  let(:session) { instance_double(Brute::Session, restore: nil) }
  let(:agent) do
    instance_double(
      "agent",
      run: nil,
      env: { metadata: { tokens: {}, timing: {}, tool_calls: 0 } },
      context: double("context"),
    )
  end

  before do
    allow(Brute::Session).to receive(:new).and_return(session)
    allow(Brute).to receive(:agent).and_return(agent)
  end

  # ── Initial state ──

  describe "initial state" do
    it "starts with 'build' as the current agent" do
      expect(repl.instance_variable_get(:@current_agent)).to eq("build")
    end

    it "passes agent_name: 'build' to Brute.agent on first ensure_agent!" do
      expect(Brute).to receive(:agent).with(hash_including(agent_name: "build")).and_return(agent)
      invoke_private(repl, :ensure_agent!)
    end
  end

  # ── cycle_agent transitions ──

  describe "#cycle_agent" do
    before do
      # cycle_agent writes ANSI escape codes to $stdout
      allow($stdout).to receive(:print)
      allow($stdout).to receive(:flush)
    end

    it "switches from build to plan" do
      invoke_private(repl, :cycle_agent)
      expect(repl.instance_variable_get(:@current_agent)).to eq("plan")
    end

    it "resets the agent (sets @agent to nil)" do
      # First create an agent
      invoke_private(repl, :ensure_agent!)
      expect(repl.instance_variable_get(:@agent)).not_to be_nil

      # Cycle should nil it out
      invoke_private(repl, :cycle_agent)
      expect(repl.instance_variable_get(:@agent)).to be_nil
    end

    it "wraps around through all agents back to build" do
      agents = BruteCLI::REPL::AGENTS
      agents.size.times { invoke_private(repl, :cycle_agent) }
      expect(repl.instance_variable_get(:@current_agent)).to eq("build")
    end

    it "preserves the session across mode switches" do
      invoke_private(repl, :ensure_agent!)
      session_before = repl.instance_variable_get(:@session)

      invoke_private(repl, :cycle_agent)
      session_after = repl.instance_variable_get(:@session)

      expect(session_after).to equal(session_before)
    end
  end

  # ── Agent recreation after switch ──

  describe "agent recreation after cycle" do
    before do
      allow($stdout).to receive(:print)
      allow($stdout).to receive(:flush)
    end

    it "passes agent_name: 'plan' after switching to plan mode" do
      invoke_private(repl, :cycle_agent) # build -> plan

      expect(Brute).to receive(:agent).with(hash_including(agent_name: "plan")).and_return(agent)
      invoke_private(repl, :ensure_agent!)
    end

    it "passes agent_name: 'build' after cycling back to build mode" do
      # Cycle through all agents back to build
      agents = BruteCLI::REPL::AGENTS
      agents.size.times do
        invoke_private(repl, :cycle_agent)
        invoke_private(repl, :ensure_agent!)
      end

      # Now we're back at "build"
      expect(repl.instance_variable_get(:@current_agent)).to eq("build")
      # Reset agent so ensure_agent! will recreate
      invoke_private(repl, :reset_agent!)

      expect(Brute).to receive(:agent).with(hash_including(agent_name: "build")).and_return(agent)
      invoke_private(repl, :ensure_agent!)
    end

    it "reuses the same session object for the new agent" do
      invoke_private(repl, :ensure_agent!)
      invoke_private(repl, :cycle_agent)

      expect(Brute).to receive(:agent).with(hash_including(session: session)).and_return(agent)
      invoke_private(repl, :ensure_agent!)
    end
  end

  # ── Regression: ensure_agent! idempotency after switch ──

  describe "ensure_agent! idempotency" do
    before do
      allow($stdout).to receive(:print)
      allow($stdout).to receive(:flush)
    end

    it "creates a new agent only once after a mode switch" do
      # Initial agent creation
      invoke_private(repl, :ensure_agent!)

      # Switch mode
      invoke_private(repl, :cycle_agent)

      # First ensure_agent! after switch should create new agent
      expect(Brute).to receive(:agent).once.with(hash_including(agent_name: "plan")).and_return(agent)
      invoke_private(repl, :ensure_agent!)

      # Second ensure_agent! should be idempotent
      invoke_private(repl, :ensure_agent!)
    end
  end

  # ── Regression: agent_switched is never passed ──

  describe "agent_switched context key (regression)" do
    before do
      allow($stdout).to receive(:print)
      allow($stdout).to receive(:flush)
    end

    it "does NOT pass agent_switched to Brute.agent" do
      # Start in plan mode
      invoke_private(repl, :cycle_agent)
      invoke_private(repl, :ensure_agent!)

      # Switch to build
      invoke_private(repl, :cycle_agent)

      # The agent factory call should NOT include agent_switched
      expect(Brute).to receive(:agent) do |**kwargs|
        expect(kwargs).not_to have_key(:agent_switched)
        agent
      end
      invoke_private(repl, :ensure_agent!)
    end
  end
end
