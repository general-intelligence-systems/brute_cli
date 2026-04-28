# frozen_string_literal: true

RSpec.describe BruteCLI::Execution, "mode switching" do
  let(:execution) { build_execution(cwd: "/tmp/test") }
  let(:agent) do
    instance_double('Brute::Agent', call: nil)
  end
  let(:session) { Brute::Session.new }

  before do
    allow(Brute::Session).to receive(:new).and_return(session)
    allow(Brute::Agent).to receive(:new).and_return(agent)
    allow(FileUtils).to receive(:mkdir_p)
  end

  # ── Initial state ──

  describe "initial state" do
    it "starts with 'build' as the current agent" do
      expect(execution.current_agent).to eq("build")
    end

    it "builds an LLM agent on first ensure_agent!" do
      expect(Brute::Agent).to receive(:new).with(
        hash_including(provider: anything, tools: Brute::Tools::ALL)
      ).and_return(agent)
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
    it "rebuilds agent after setting current_agent to plan" do
      execution.current_agent = "plan"
      execution.agent = nil

      expect(Brute::Agent).to receive(:new).and_return(agent)
      execution.ensure_agent!
    end

    it "preserves the same session object for the new agent" do
      execution.ensure_agent!
      execution.current_agent = "plan"
      execution.agent = nil

      expect(Brute::Agent).to receive(:new).and_return(agent)
      execution.ensure_agent!
      expect(execution.instance_variable_get(:@session)).to equal(session)
    end
  end

  # ── ensure_agent! idempotency ──

  describe "ensure_agent! idempotency" do
    it "creates a new agent only once after a mode switch" do
      execution.ensure_agent!

      execution.current_agent = "plan"
      execution.agent = nil

      expect(Brute::Agent).to receive(:new).once.and_return(agent)
      execution.ensure_agent!

      # Second call should be idempotent
      execution.ensure_agent!
    end
  end

  # ── Shell agent mode ──

  describe "shell agent mode" do
    it "builds a shell agent for bash" do
      execution.current_agent = "bash"
      execution.agent = nil

      expect(Brute::Agent).to receive(:new).with(
        hash_including(provider: :shell, model: "bash")
      ).and_return(agent)
      execution.ensure_agent!
    end

    it "builds a shell agent for ruby" do
      execution.current_agent = "ruby"
      execution.agent = nil

      expect(Brute::Agent).to receive(:new).with(
        hash_including(provider: :shell, model: "ruby")
      ).and_return(agent)
      execution.ensure_agent!
    end
  end
end
