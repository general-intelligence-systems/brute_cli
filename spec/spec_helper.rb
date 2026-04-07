# frozen_string_literal: true

require 'brute_cli'

# Disable TTY dependencies during tests
RSpec.configure do |config|
  # Stub terminal dimensions to avoid TTY dependency
  config.before(:each) do
    allow(IO).to receive(:console).and_return(nil)
    allow(TTY::Screen).to receive(:width).and_return(80)
  end

  # Stub bat so tests don't shell out to the real binary
  config.before(:each) do
    allow(BruteCLI::Bat).to receive(:markdown_mode) { |text, **| text }
    allow(BruteCLI::Bat).to receive(:diff_mode) { |text, **| text }
  end
end

# Helpers for capturing stdout/stderr
module TestHelpers
  def capture_stdout(&block)
    original = $stdout
    $stdout = StringIO.new
    block.call
    $stdout.string
  ensure
    $stdout = original
  end

  def capture_stderr(&block)
    original = $stderr
    $stderr = StringIO.new
    block.call
    $stderr.string
  ensure
    $stderr = original
  end

  # Build an Execution instance with stubbed dependencies
  def build_execution(**options)
    defaults = { cwd: '/tmp/test', session_id: nil }
    BruteCLI::Execution.new(defaults.merge(options))
  end

  # Build a REPL instance with stubbed dependencies
  def build_repl(**options)
    defaults = { cwd: '/tmp/test', session_id: nil }
    BruteCLI::REPL.new(defaults.merge(options))
  end

  # Access private methods for testing
  def invoke_private(obj, method_name, *args, **kwargs, &block)
    obj.send(method_name, *args, **kwargs, &block)
  end
end

RSpec.configure do |config|
  config.include TestHelpers
end
