# frozen_string_literal: true

RSpec.describe BruteCLI::StreamFormatter do
  let(:output) { StringIO.new }
  let(:streamer) { described_class.new(output: output, width: 80) }

  def rendered
    output.string
  end

  # Strip ANSI escape sequences for content assertions
  def plain(text)
    text.gsub(/\e\[[0-9;]*[A-Za-z]/, "")
  end

  describe "#<<" do
    it "prints raw characters immediately for sub-line tokens" do
      streamer << "hel"
      expect(rendered).to include("hel")
    end

    it "re-renders through TTY::Markdown on newline" do
      streamer << "# Hello\n"
      # TTY::Markdown converts "# Hello" -> styled "Hello" (strips the #)
      text = plain(rendered)
      expect(text).to include("Hello")
    end

    it "renders bold as styled text" do
      streamer << "This is **bold** text\n"
      # TTY::Markdown strips ** and applies ANSI bold
      text = plain(rendered)
      expect(text).to include("bold")
    end

    it "handles multiple lines from a single chunk" do
      streamer << "line one\nline two\n"
      text = plain(rendered)
      expect(text).to include("line one")
      expect(text).to include("line two")
    end

    it "handles tokens split across multiple calls" do
      streamer << "# Hel"
      streamer << "lo World"
      streamer << "\n"
      text = plain(rendered)
      expect(text).to include("Hello World")
    end

    it "prints empty lines without error" do
      expect { streamer << "\n" }.not_to raise_error
    end
  end

  describe "fenced code blocks" do
    it "renders code blocks with syntax highlighting" do
      streamer << "```ruby\ndef hello\n  puts 'world'\nend\n```\n"
      text = plain(rendered)
      expect(text).to include("def hello")
      expect(text).to include("puts")
      expect(rendered).to include("\e[")
    end

    it "renders content after a closed code block" do
      streamer << "```ruby\nx = 1\n```\n# Back to markdown\n"
      text = plain(rendered)
      expect(text).to include("Back to markdown")
    end
  end

  describe "#flush" do
    it "finalizes a partial line" do
      streamer << "partial text"
      streamer.flush
      text = plain(rendered)
      expect(text).to include("partial text")
    end

    it "is a no-op when buffer is empty" do
      expect { streamer.flush }.not_to raise_error
      expect(rendered).to eq("")
    end

    it "adds a trailing newline" do
      streamer << "hello"
      streamer.flush
      expect(rendered).to end_with("\n")
    end
  end

  describe "#reset" do
    it "clears all state" do
      streamer << "old content\n"
      streamer.reset
      streamer << "fresh start\n"
      text = plain(rendered)
      expect(text).to include("fresh start")
    end
  end

  describe "thread safety" do
    it "handles concurrent writes without corruption" do
      errors = []
      threads = 4.times.map do |t|
        Thread.new do
          50.times do |i|
            streamer << "t#{t}i#{i} "
          end
        rescue => e
          errors << e
        end
      end
      threads.each(&:join)
      expect(errors).to be_empty
    end
  end
end
