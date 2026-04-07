# frozen_string_literal: true

RSpec.describe BruteCLI::REPL do
  let(:repl) { build_repl }
  let(:agent) do
    instance_double(
      'agent',
      env: {
        metadata: {
          tokens: { total: 150, total_input: 100, total_output: 50 },
          timing: { total_elapsed: 45.5 },
          tool_calls: 5
        }
      }
    )
  end

  before do
    repl.instance_variable_set(:@agent, agent)
    repl.instance_variable_set(:@provider_name, 'anthropic')
    repl.instance_variable_set(:@model_name, 'claude-3.5-sonnet')
  end

  describe '#print_stats_bar' do
    it 'prints token stats' do
      output = capture_stdout { invoke_private(repl, :print_stats_bar) }
      expect(output).to include('tokens')
      expect(output).to include('150')
    end

    it 'prints timing stats' do
      output = capture_stdout { invoke_private(repl, :print_stats_bar) }
      expect(output).to include('time')
      expect(output).to include('45.5')
    end

    it 'includes tool count when > 0' do
      output = capture_stdout { invoke_private(repl, :print_stats_bar) }
      expect(output).to include('tools')
      expect(output).to include('5')
    end

    it 'omits tool count when 0' do
      allow(agent).to receive(:env).and_return({
        metadata: {
          tokens: { total: 100 },
          timing: { total_elapsed: 10 },
          tool_calls: 0
        }
      })
      output = capture_stdout { invoke_private(repl, :print_stats_bar) }
      expect(output).not_to include('tools')
    end

    it 'handles missing metadata gracefully' do
      allow(agent).to receive(:env).and_return({ metadata: {} })
      output = capture_stdout { invoke_private(repl, :print_stats_bar) }
      expect(output).to include('tokens')
      expect(output).to include('0')
    end

    it 'handles nil agent' do
      repl.instance_variable_set(:@agent, nil)
      output = capture_stdout { invoke_private(repl, :print_stats_bar) }
      expect(output).to include('tokens')
    end
  end

  describe '#stat_span' do
    it 'formats label and value with colors' do
      result = invoke_private(repl, :stat_span, 'tokens', '150')
      expect(result).to include('tokens')
      expect(result).to include('150')
    end
  end

  describe '#print_model_line' do
    it 'prints provider and model info' do
      output = capture_stdout { invoke_private(repl, :print_model_line) }
      expect(output).to include('anthropic')
      expect(output).to include('brute')
    end
  end

  describe '#resolve_provider_info' do
    context 'when Brute.provider succeeds' do
      let(:provider) { double('provider', name: :anthropic, default_model: 'claude-3') }

      before do
        allow(Brute).to receive(:provider).and_return(provider)
      end

      it 'sets provider_name and model_name' do
        invoke_private(repl, :resolve_provider_info)
        expect(repl.instance_variable_get(:@provider_name)).to eq('anthropic')
        expect(repl.instance_variable_get(:@model_name)).to eq('claude-3')
      end
    end

    context 'when Brute.provider raises' do
      before do
        allow(Brute).to receive(:provider).and_raise(StandardError)
      end

      it 'sets both to nil' do
        invoke_private(repl, :resolve_provider_info)
        expect(repl.instance_variable_get(:@provider_name)).to be_nil
        expect(repl.instance_variable_get(:@model_name)).to be_nil
      end
    end
  end

  describe '#build_subtitle' do
    before do
      repl.instance_variable_set(:@provider_name, 'openai')
      repl.instance_variable_set(:@model_name, 'gpt-4')
    end

    it 'includes provider and model' do
      result = invoke_private(repl, :build_subtitle)
      expect(result).to include('openai')
      expect(result).to include('gpt-4')
      expect(result).to include('brute')
    end
  end

  describe '#stat_span' do
    it 'formats label and value' do
      result = invoke_private(repl, :stat_span, 'provider', 'anthropic')
      expect(result).to include('provider')
      expect(result).to include('anthropic')
    end
  end
end
