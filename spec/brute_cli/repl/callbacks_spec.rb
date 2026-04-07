# frozen_string_literal: true

RSpec.describe BruteCLI::REPL do
  let(:repl) { build_repl }
  let(:spinner) { instance_double(TTY::Spinner, spinning?: true, stop: nil) }

  before do
    repl.instance_variable_set(:@spinner, spinner)
  end

  describe '#on_content' do
    it 'stops the spinner' do
      expect(spinner).to receive(:stop)
      invoke_private(repl, :on_content, 'new text')
    end

    it 'appends text to content buffer' do
      repl.instance_variable_set(:@content_buf, +'existing ')
      allow(spinner).to receive(:stop)

      invoke_private(repl, :on_content, 'new text')

      expect(repl.instance_variable_get(:@content_buf)).to eq('existing new text')
    end

    it 'streams text to the streamer for immediate output' do
      streamer = repl.instance_variable_get(:@streamer)
      allow(spinner).to receive(:stop)
      expect(streamer).to receive(:<<).with('hello')
      invoke_private(repl, :on_content, 'hello')
    end
  end

  describe '#on_reasoning' do
    it 'is a no-op' do
      expect { invoke_private(repl, :on_reasoning, 'reasoning text') }.not_to raise_error
    end
  end

  describe '#on_tool_call' do
    before do
      repl.instance_variable_set(:@content_buf, 'Some content')
      allow(spinner).to receive(:stop)
      allow(repl).to receive(:flush_content)
    end

    it 'stops the spinner' do
      expect(spinner).to receive(:stop)
      invoke_private(repl, :on_tool_call, 'read', { 'file_path' => 'test.rb' })
    end

    it 'flushes content buffer' do
      expect(repl).to receive(:flush_content)
      invoke_private(repl, :on_tool_call, 'read', {})
    end

    it 'stores pending tool info' do
      invoke_private(repl, :on_tool_call, 'write', { 'file_path' => 'test.rb' })
      pending = repl.instance_variable_get(:@pending_tool)
      expect(pending[:name]).to eq('write')
      expect(pending[:args]).to eq({ 'file_path' => 'test.rb' })
    end
  end

  describe '#on_tool_result' do
    let(:new_spinner) { instance_double(TTY::Spinner, auto_spin: nil) }

    before do
      repl.instance_variable_set(:@pending_tool, { name: 'read', args: {} })
      allow(spinner).to receive(:stop)
      allow(TTY::Spinner).to receive(:new).and_return(new_spinner)
    end

    it 'stops the spinner' do
      expect(spinner).to receive(:stop)
      invoke_private(repl, :on_tool_result, 'read', { content: 'data' })
    end

    it 'calls print_tool_result' do
      allow(repl).to receive(:print_tool_result)
      expect(repl).to receive(:print_tool_result)
      invoke_private(repl, :on_tool_result, 'read', { content: 'data' })
    end

    it 'clears pending_tool after rendering' do
      allow(repl).to receive(:print_tool_result)
      invoke_private(repl, :on_tool_result, 'read', {})
      expect(repl.instance_variable_get(:@pending_tool)).to be_nil
    end

    it 'restarts spinner after rendering' do
      allow(repl).to receive(:print_tool_result)
      expect(new_spinner).to receive(:auto_spin)
      invoke_private(repl, :on_tool_result, 'read', {})
    end

    it 'uses passed name when pending_tool is nil' do
      repl.instance_variable_set(:@pending_tool, nil)
      allow(repl).to receive(:print_tool_result)
      expect(repl).to receive(:print_tool_result).with(
        { name: 'fetch', args: {} },
        anything
      )
      invoke_private(repl, :on_tool_result, 'fetch', {})
    end
  end

  describe 'TOOL_ICONS constant' do
    it 'maps tool names to emoji' do
      icons = described_class::TOOL_ICONS
      expect(icons['read']).to eq(BruteCLI::Emoji::EYES)
      expect(icons['shell']).to eq(BruteCLI::Emoji::COMPUTER)
      expect(icons['write']).to eq(BruteCLI::Emoji::WRITING)
    end
  end

  describe '@last_output separator deduplication' do
    let(:new_spinner) { instance_double(TTY::Spinner, auto_spin: nil) }

    before do
      repl.instance_variable_set(:@pending_tool, { name: 'read', args: {} })
      allow(spinner).to receive(:stop)
      allow(TTY::Spinner).to receive(:new).and_return(new_spinner)
    end

    it 'prints separator before tool result when last output was content' do
      repl.instance_variable_set(:@last_output, :content)
      allow(repl).to receive(:print_tool_result)

      output = capture_stdout { invoke_private(repl, :on_tool_result, 'read', {}) }
      sep = invoke_private(repl, :separator)
      # Should contain at least one separator (from on_tool_result itself)
      expect(output).to include('─')
    end

    it 'skips separator in on_tool_result when last output is already a separator' do
      repl.instance_variable_set(:@last_output, :separator)
      allow(repl).to receive(:print_tool_result)

      output = capture_stdout { invoke_private(repl, :on_tool_result, 'read', {}) }
      # on_tool_result should NOT print a separator, but start_spinner will print one
      # Count separators: should only be one (from start_spinner, since last_output
      # was :tool after print_tool_result, not :separator)
      sep_line = invoke_private(repl, :separator)
      lines = output.lines.map(&:strip).select { |l| l == sep_line.strip }
      # Only the separator from start_spinner (after tool result sets @last_output = :tool)
      expect(lines.size).to eq(1)
    end

    it 'skips separator in start_spinner when last output is already a separator' do
      repl.instance_variable_set(:@spinner, nil)
      repl.instance_variable_set(:@last_output, :separator)

      output = capture_stdout { invoke_private(repl, :start_spinner, 'Thinking...') }
      sep_line = invoke_private(repl, :separator)
      lines = output.lines.map(&:strip).select { |l| l == sep_line.strip }
      expect(lines.size).to eq(0)
    end

    it 'prints separator in start_spinner when last output was content' do
      repl.instance_variable_set(:@spinner, nil)
      repl.instance_variable_set(:@last_output, :content)

      output = capture_stdout { invoke_private(repl, :start_spinner, 'Thinking...') }
      expect(output).to include('─')
    end

    it 'prints separator in start_spinner when last output was tool' do
      repl.instance_variable_set(:@spinner, nil)
      repl.instance_variable_set(:@last_output, :tool)

      output = capture_stdout { invoke_private(repl, :start_spinner, 'Thinking...') }
      expect(output).to include('─')
    end

    it 'sets last_output to :content on on_content' do
      invoke_private(repl, :on_content, 'hello')
      expect(repl.instance_variable_get(:@last_output)).to eq(:content)
    end

    it 'sets last_output to :tool after on_tool_result' do
      allow(repl).to receive(:print_tool_result)
      invoke_private(repl, :on_tool_result, 'read', {})
      # start_spinner sets it to :separator at the end, but the tool result
      # itself sets :tool first — verify the final state is :separator
      # (because start_spinner runs last inside on_tool_result)
      expect(repl.instance_variable_get(:@last_output)).to eq(:separator)
    end

    it 'sets last_output to :separator after start_spinner' do
      repl.instance_variable_set(:@spinner, nil)
      repl.instance_variable_set(:@last_output, :content)
      capture_stdout { invoke_private(repl, :start_spinner, 'Thinking...') }
      expect(repl.instance_variable_get(:@last_output)).to eq(:separator)
    end

    it 'consecutive tool results produce only one separator between them' do
      # Simulate: tool_result → tool_result (no content in between)
      # First tool result starts with @last_output = nil
      repl.instance_variable_set(:@last_output, nil)
      allow(repl).to receive(:print_tool_result)

      # First on_tool_result
      output1 = capture_stdout { invoke_private(repl, :on_tool_result, 'read', {}) }

      # After on_tool_result, @last_output is :separator (set by start_spinner)
      expect(repl.instance_variable_get(:@last_output)).to eq(:separator)

      # Second on_tool_result (last_output is now :separator from start_spinner)
      repl.instance_variable_set(:@pending_tool, { name: 'write', args: {} })
      # Replace the spinner with a fresh stub
      second_spinner = instance_double(TTY::Spinner, auto_spin: nil)
      repl.instance_variable_set(:@spinner, new_spinner)
      allow(new_spinner).to receive(:spinning?).and_return(true)
      allow(new_spinner).to receive(:stop)
      allow(TTY::Spinner).to receive(:new).and_return(second_spinner)

      output2 = capture_stdout { invoke_private(repl, :on_tool_result, 'write', {}) }

      sep_line = invoke_private(repl, :separator)
      # Second call should NOT have a separator at the start (it was already :separator)
      # It will have one from start_spinner at the end (since @last_output becomes :tool first)
      seps_in_output2 = output2.lines.map(&:strip).count { |l| l == sep_line.strip }
      expect(seps_in_output2).to eq(1) # only the one from start_spinner
    end

    it 'does not set last_output to :content when flush_content has blank buffer' do
      repl.instance_variable_set(:@content_buf, +'')
      repl.instance_variable_set(:@last_output, :separator)
      invoke_private(repl, :flush_content)
      expect(repl.instance_variable_get(:@last_output)).to eq(:separator)
    end

    it 'sets last_output to :content when flush_content has real content' do
      repl.instance_variable_set(:@content_buf, +'Hello world')
      streamer = repl.instance_variable_get(:@streamer)
      streamer << 'Hello world'
      repl.instance_variable_set(:@last_output, :separator)
      capture_stdout { invoke_private(repl, :flush_content) }
      expect(repl.instance_variable_get(:@last_output)).to eq(:content)
    end
  end

  # ── Bug: no thread safety on shared REPL state ───────────────────────
  #
  # In streaming mode, on_content fires inline with the SSE parser (main
  # thread), while on_tool_result fires from a background Thread spawned
  # by AgentStream#spawn_with_callback. Both mutate @content_buf,
  # @spinner, and @pending_tool with no synchronization.
  #
  # These tests will FAIL (raise exceptions or corrupt state) until a
  # mutex is added to protect callback state.

  describe 'thread safety' do
    let(:new_spinner) { instance_double(TTY::Spinner, auto_spin: nil, spinning?: false, stop: nil) }
    let(:sink) { StringIO.new }

    before do
      # Use a real nil spinner so stop_spinner doesn't blow up across threads
      repl.instance_variable_set(:@spinner, nil)
      repl.instance_variable_set(:@content_buf, +'')
      repl.instance_variable_set(:@pending_tool, nil)
      # Point streamer output at our sink so it doesn't pollute stdout
      repl.instance_variable_set(:@streamer, BruteCLI::StreamFormatter.new(output: sink))
      allow(TTY::Spinner).to receive(:new).and_return(new_spinner)
      allow(new_spinner).to receive(:spinning?).and_return(false)
    end

    it 'does not corrupt content buffer under concurrent on_content calls' do
      # Simulate the streaming parser firing on_content from multiple threads
      # (e.g., main thread + tool result thread both touching @content_buf)
      iterations = 200
      errors = []

      threads = 4.times.map do |t|
        Thread.new do
          iterations.times do |i|
            invoke_private(repl, :on_content, "t#{t}i#{i} ")
          end
        rescue => e
          errors << e
        end
      end
      threads.each(&:join)

      expect(errors).to be_empty,
        "Concurrent on_content raised: #{errors.map(&:message).join(', ')}. " \
        "The content buffer needs mutex protection."

      buf = repl.instance_variable_get(:@content_buf)
      # Each thread wrote `iterations` chunks. Total chunks = 4 * iterations.
      # We can't assert exact ordering, but we can assert nothing was lost.
      chunk_count = buf.scan(/t\di\d+/).size
      expect(chunk_count).to eq(4 * iterations),
        "Expected #{4 * iterations} chunks in buffer but found #{chunk_count}. " \
        "Concurrent writes corrupted the buffer."
    end

    it 'does not lose buffered content when on_tool_call races with on_content' do
      # Scenario: on_content is buffering text on thread A, while
      # on_tool_call fires on thread B (calling flush_content).
      # Without a mutex, flush_content can clear the buffer while
      # on_content is mid-append, or content appended between the
      # strip.empty? check and the clear can be lost.

      # Intercept puts/write for capturing flushed content
      flushed = []
      allow($stdout).to receive(:puts) do |*args|
        flushed << args.first if args.first.is_a?(String) && !args.first.empty?
      end
      allow($stdout).to receive(:write)

      iterations = 100
      barrier = Thread.new { sleep } # Simple barrier

      content_thread = Thread.new do
        barrier.join rescue nil
        iterations.times do |i|
          invoke_private(repl, :on_content, "chunk#{i} ")
          sleep(0.0001) if i % 10 == 0
        end
      end

      tool_thread = Thread.new do
        barrier.join rescue nil
        (iterations / 10).times do
          # Simulate on_tool_call which flushes content
          invoke_private(repl, :on_tool_call, 'read', {})
          sleep(0.001)
        end
      end

      barrier.kill # Release both threads
      content_thread.join
      tool_thread.join

      # Flush any remaining content
      capture_stdout { invoke_private(repl, :flush_content) }

      # Collect all content: flushed + remaining buffer + streamer output
      remaining = repl.instance_variable_get(:@content_buf)
      all_output = (flushed + [remaining, sink.string]).join

      # Every chunk should appear somewhere — either flushed or still buffered
      missing = (0...iterations).reject { |i| all_output.include?("chunk#{i}") }
      expect(missing).to be_empty,
        "Content chunks #{missing.first(5).map { |i| "chunk#{i}" }.join(', ')} were lost. " \
        "on_tool_call's flush_content raced with on_content, dropping buffered text. " \
        "A mutex is needed to protect @content_buf."
    end
  end
end
