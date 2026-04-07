# frozen_string_literal: true

RSpec.describe BruteCLI::Bat do
  let(:success_status) { instance_double(Process::Status, success?: true) }
  let(:failure_status) { instance_double(Process::Status, success?: false) }

  # Reset memoised state between tests
  before(:each) do
    BruteCLI::Bat.instance_variable_set(:@bat_missing_warned, false)
    BruteCLI::Bat.remove_instance_variable(:@available) if BruteCLI::Bat.instance_variable_defined?(:@available)
  end

  describe '.available?' do
    it 'returns true when bat is on PATH' do
      allow(File).to receive(:executable?).and_call_original
      allow(File).to receive(:executable?).with(include("bat")).and_return(true)

      expect(BruteCLI::Bat.available?).to be true
    end

    it 'returns false when bat is not on PATH' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("PATH").and_return("/empty")
      allow(ENV).to receive(:to_s).and_return("/empty")
      stub_const("ENV", { "PATH" => "/empty" })

      # Re-clear the memoised value after stubbing
      BruteCLI::Bat.remove_instance_variable(:@available) if BruteCLI::Bat.instance_variable_defined?(:@available)

      expect(BruteCLI::Bat.available?).to be false
    end
  end

  describe '.run' do

    it 'returns highlighted output when bat succeeds' do
      allow(Open3).to receive(:capture2).and_return(["highlighted output", success_status])

      result = BruteCLI::Bat.run("raw text", language: "markdown", style: "plain")
      expect(result).to eq("highlighted output")
    end

    it 'passes the correct flags to bat' do
      allow(Open3).to receive(:capture2).and_return(["out", success_status])

      BruteCLI::Bat.run("text", language: "diff", style: "numbers,grid", width: 100)

      expect(Open3).to have_received(:capture2).with(
        BruteCLI::Bat::BAT_BIN,
        "--color=always",
        "--paging=never",
        "--language=diff",
        "--style=numbers,grid",
        "--terminal-width=100",
        stdin_data: "text"
      )
    end

    it 'returns raw text when bat exits non-zero' do
      allow(Open3).to receive(:capture2).and_return(["", failure_status])

      result = BruteCLI::Bat.run("raw text", language: "markdown", style: "plain")
      expect(result).to eq("raw text")
    end

    it 'returns raw text when bat is not found (graceful degradation)' do
      allow(Open3).to receive(:capture2).and_raise(Errno::ENOENT)

      result = BruteCLI::Bat.run("raw text", language: "markdown", style: "plain")
      expect(result).to eq("raw text")
    end

    it 'prints a styled warning to stderr when bat is not found' do
      allow(Open3).to receive(:capture2).and_raise(Errno::ENOENT)

      output = capture_stderr { BruteCLI::Bat.run("text", language: "markdown", style: "plain") }
      expect(output).to include("bat not found")
      expect(output).to include("diff syntax highlighting")
    end

    it 'only warns once about missing bat' do
      allow(Open3).to receive(:capture2).and_raise(Errno::ENOENT)

      first_output = capture_stderr { BruteCLI::Bat.run("text", language: "markdown", style: "plain") }
      second_output = capture_stderr { BruteCLI::Bat.run("text", language: "markdown", style: "plain") }

      expect(first_output).to include("bat not found")
      expect(second_output).to eq("")
    end
  end

  describe '.markdown_mode' do
    it 'delegates to .run with markdown language and plain style' do
      # Unstub the global spec_helper stub so the real method flows through to .run
      allow(BruteCLI::Bat).to receive(:markdown_mode).and_call_original
      allow(Open3).to receive(:capture2).and_return(["rendered", success_status])

      result = BruteCLI::Bat.markdown_mode("# Hello", width: 120)

      expect(Open3).to have_received(:capture2).with(
        BruteCLI::Bat::BAT_BIN,
        "--color=always", "--paging=never",
        "--language=markdown", "--style=plain", "--terminal-width=120",
        stdin_data: "# Hello"
      )
      expect(result).to eq("rendered")
    end

    it 'defaults width to 80' do
      allow(BruteCLI::Bat).to receive(:markdown_mode).and_call_original
      allow(Open3).to receive(:capture2).and_return(["out", success_status])

      BruteCLI::Bat.markdown_mode("text")

      expect(Open3).to have_received(:capture2).with(
        BruteCLI::Bat::BAT_BIN,
        "--color=always", "--paging=never",
        "--language=markdown", "--style=plain", "--terminal-width=80",
        stdin_data: "text"
      )
    end
  end

  describe '.diff_mode' do
    it 'delegates to .run with diff language and numbers,grid style' do
      allow(BruteCLI::Bat).to receive(:diff_mode).and_call_original
      allow(Open3).to receive(:capture2).and_return(["rendered", success_status])

      result = BruteCLI::Bat.diff_mode("--- a/file\n+++ b/file", width: 100)

      expect(Open3).to have_received(:capture2).with(
        BruteCLI::Bat::BAT_BIN,
        "--color=always", "--paging=never",
        "--language=diff", "--style=numbers,grid", "--terminal-width=100",
        stdin_data: "--- a/file\n+++ b/file"
      )
      expect(result).to eq("rendered")
    end

    it 'defaults width to 80' do
      allow(BruteCLI::Bat).to receive(:diff_mode).and_call_original
      allow(Open3).to receive(:capture2).and_return(["out", success_status])

      BruteCLI::Bat.diff_mode("diff text")

      expect(Open3).to have_received(:capture2).with(
        BruteCLI::Bat::BAT_BIN,
        "--color=always", "--paging=never",
        "--language=diff", "--style=numbers,grid", "--terminal-width=80",
        stdin_data: "diff text"
      )
    end
  end
end
