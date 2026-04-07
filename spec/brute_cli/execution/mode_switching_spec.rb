# frozen_string_literal: true

RSpec.describe BruteCLI::Execution, "mode switching" do
  let(:execution) { build_execution(cwd: "/tmp/test") }
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
      expect(execution.current_agent).to eq("build")
    end

    it "passes agent_name: 'build' to Brute.agent on first ensure_agent!" do
      expect(Brute).to receive(:agent).with(hash_including(agent_name: "build")).and_return(agent)
      execution.ensure_agent!
    end
  end

  # ── current_agent= writer ──

  describe "#current_agent=" do
    it "changes the current agent" do
      execution.current_agent = "plan"
      expect(execution.current_agent).to eq("plan")
    end
  end

  # ── agent accessor ──

  describe "#agent=" do
    it "nils out agent so ensure_agent! recreates it" do
      execution.ensure_agent!
      expect(execution.agent).not_to be_nil

      execution.agent = nil
      expect(execution.agent).to be_nil
    end

    it "preserves the session across resets" do
      execution.ensure_agent!
      session_before = execution.instance_variable_get(:@session)

      execution.agent = nil
      session_after = execution.instance_variable_get(:@session)

      expect(session_after).to equal(session_before)
    end
  end

  # ── Agent recreation after switching current_agent ──

  describe "agent recreation after switching current_agent" do
    it "passes agent_name: 'plan' after setting current_agent to plan" do
      execution.current_agent = "plan"
      execution.agent = nil

      expect(Brute).to receive(:agent).with(hash_including(agent_name: "plan")).and_return(agent)
      execution.ensure_agent!
    end

    it "passes the same session object for the new agent" do
      execution.ensure_agent!
      execution.current_agent = "plan"
      execution.agent = nil

      expect(Brute).to receive(:agent).with(hash_including(session: session)).and_return(agent)
      execution.ensure_agent!
    end
  end

  # ── ensure_agent! idempotency ──

  describe "ensure_agent! idempotency" do
    it "creates a new agent only once after a mode switch" do
      execution.ensure_agent!

      execution.current_agent = "plan"
      execution.agent = nil

      expect(Brute).to receive(:agent).once.with(hash_including(agent_name: "plan")).and_return(agent)
      execution.ensure_agent!

      # Second call should be idempotent
      execution.ensure_agent!
    end
  end

  # ── Regression: agent_switched is never passed ──

  describe "agent_switched context key (regression)" do
    it "does NOT pass agent_switched to Brute.agent" do
      execution.current_agent = "plan"
      execution.agent = nil
      execution.ensure_agent!

      execution.current_agent = "build"
      execution.agent = nil

      expect(Brute).to receive(:agent) do |**kwargs|
        expect(kwargs).not_to have_key(:agent_switched)
        agent
      end
      execution.ensure_agent!
    end
  end
end
