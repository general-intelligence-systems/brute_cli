# frozen_string_literal: true

RSpec.describe BruteCLI::Execution do
  let(:execution) { build_execution }

  describe '#print_stats_bar' do
    it 'prints token stats from event handler metadata' do
      handler = BruteCLI::CLIEventHandler.new(
        Brute::Pipeline::NullSink.new, execution: execution
      )
      handler.instance_variable_get(:@metadata).merge!(
        tokens: { total: 150, total_input: 100, total_output: 50 },
        timing: { total_elapsed: 45.5 },
        tool_calls: 5,
      )
      execution.instance_variable_set(:@event_handler, handler)

      output = capture_stdout { invoke_private(execution, :print_stats_bar) }
      expect(output).to include('tokens')
      expect(output).to include('150')
    end

    it 'prints timing stats' do
      handler = BruteCLI::CLIEventHandler.new(
        Brute::Pipeline::NullSink.new, execution: execution
      )
      handler.instance_variable_get(:@metadata)[:timing] = { total_elapsed: 45.5 }
      execution.instance_variable_set(:@event_handler, handler)

      output = capture_stdout { invoke_private(execution, :print_stats_bar) }
      expect(output).to include('time')
      expect(output).to include('45.5')
    end

    it 'includes tool count when > 0' do
      handler = BruteCLI::CLIEventHandler.new(
        Brute::Pipeline::NullSink.new, execution: execution
      )
      handler.instance_variable_get(:@metadata)[:tool_calls] = 5
      execution.instance_variable_set(:@event_handler, handler)

      output = capture_stdout { invoke_private(execution, :print_stats_bar) }
      expect(output).to include('tools')
      expect(output).to include('5')
    end

    it 'omits tool count when 0' do
      handler = BruteCLI::CLIEventHandler.new(
        Brute::Pipeline::NullSink.new, execution: execution
      )
      execution.instance_variable_set(:@event_handler, handler)

      output = capture_stdout { invoke_private(execution, :print_stats_bar) }
      expect(output).not_to include('tools')
    end

    it 'handles missing event handler gracefully' do
      execution.instance_variable_set(:@event_handler, nil)
      output = capture_stdout { invoke_private(execution, :print_stats_bar) }
      expect(output).to include('tokens')
      expect(output).to include('0')
    end
  end

  describe '#resolve_provider_info' do
    context 'when Brute.provider returns a symbol' do
      before do
        allow(Brute).to receive(:provider).and_return(:anthropic)
      end

      it 'sets provider_name to the symbol string' do
        execution.resolve_provider_info
        expect(execution.provider_name).to eq('anthropic')
      end

      it 'sets model_name to nil when no model selected' do
        execution.resolve_provider_info
        expect(execution.model_name).to be_nil
      end

      it 'uses selected_model when set' do
        execution.selected_model = 'claude-sonnet-4-20250514'
        execution.resolve_provider_info
        expect(execution.model_name).to eq('claude-sonnet-4-20250514')
      end
    end

    context 'when Brute.provider raises' do
      before do
        allow(Brute).to receive(:provider).and_raise(StandardError)
      end

      it 'sets both to nil' do
        execution.resolve_provider_info
        expect(execution.provider_name).to be_nil
        expect(execution.model_name).to be_nil
      end
    end

    context 'with shell agent' do
      it 'sets provider to shell and model to the interpreter' do
        execution.current_agent = 'bash'
        execution.resolve_provider_info
        expect(execution.provider_name).to eq('shell')
        expect(execution.model_name).to eq('bash')
      end
    end
  end
end
