# frozen_string_literal: true

RSpec.describe BruteCLI::REPL do
  let(:repl) { build_repl }

  describe '#format_time' do
    it 'formats seconds under 60' do
      expect(invoke_private(repl, :format_time, 0.5)).to eq('0.5s')
      expect(invoke_private(repl, :format_time, 45.3)).to eq('45.3s')
    end

    it 'formats seconds over 60 as minutes' do
      expect(invoke_private(repl, :format_time, 90.3)).to eq('1m30.3s')
      expect(invoke_private(repl, :format_time, 125.0)).to eq('2m5.0s')
    end

    it 'formats whole minutes without seconds' do
      expect(invoke_private(repl, :format_time, 60.0)).to eq('1m0.0s')
    end
  end

  describe '#error_result?' do
    it 'returns truthy value when result has :error key' do
      result = invoke_private(repl, :error_result?, { error: 'Something failed' })
      expect(result).to be_truthy
      expect(result).to eq('Something failed')
    end

    it 'returns truthy value when result has "error" string key' do
      result = invoke_private(repl, :error_result?, { 'error' => 'Something failed' })
      expect(result).to be_truthy
      expect(result).to eq('Something failed')
    end

    it 'returns falsy value when result has no error' do
      result = invoke_private(repl, :error_result?, { content: 'success' })
      expect(result).to be_falsy
    end

    it 'returns false for non-hash results' do
      expect(invoke_private(repl, :error_result?, 'string result')).to be false
      expect(invoke_private(repl, :error_result?, nil)).to be false
    end
  end

  describe '#error_message' do
    it 'extracts :message key' do
      expect(invoke_private(repl, :error_message, { message: 'Error occurred' })).to eq('Error occurred')
    end

    it 'extracts "message" string key' do
      expect(invoke_private(repl, :error_message, { 'message' => 'Error occurred' })).to eq('Error occurred')
    end

    it 'falls back to :error key' do
      expect(invoke_private(repl, :error_message, { error: 'Failed' })).to eq('Failed')
    end

    it 'returns empty string for non-hash' do
      expect(invoke_private(repl, :error_message, 'string')).to eq('')
    end
  end

  describe '#tool_summary' do
    it 'extracts file_path from args' do
      tool = { args: { 'file_path' => 'test.rb' } }
      result = invoke_private(repl, :tool_summary, tool)
      expect(result).to include('test.rb')
    end

    it 'extracts file_path from symbol key' do
      tool = { args: { file_path: 'test.rb' } }
      result = invoke_private(repl, :tool_summary, tool)
      expect(result).to include('test.rb')
    end

    it 'extracts command from args' do
      tool = { args: { 'command' => 'ls -la' } }
      result = invoke_private(repl, :tool_summary, tool)
      expect(result).to include('ls -la')
    end

    it 'extracts pattern from args' do
      tool = { args: { 'pattern' => '*.rb' } }
      result = invoke_private(repl, :tool_summary, tool)
      expect(result).to include('*.rb')
    end

    it 'returns empty string when no relevant args' do
      tool = { args: { 'other' => 'value' } }
      expect(invoke_private(repl, :tool_summary, tool)).to eq('')
    end

    it 'returns empty string when args is empty' do
      tool = { args: {} }
      expect(invoke_private(repl, :tool_summary, tool)).to eq('')
    end
  end

  describe '#model_short' do
    before do
      repl.instance_variable_set(:@model_name, model_name)
    end

    context 'with claude model' do
      let(:model_name) { 'claude-3.5-sonnet-20240620' }

      it 'strips claude- prefix and date suffix' do
        expect(invoke_private(repl, :model_short)).to eq('3.5-sonnet')
      end
    end

    context 'with non-claude model' do
      let(:model_name) { 'gpt-4-turbo' }

      it 'returns the full name' do
        expect(invoke_private(repl, :model_short)).to eq('gpt-4-turbo')
      end
    end

    context 'with nil model' do
      let(:model_name) { nil }

      it 'returns nil' do
        expect(invoke_private(repl, :model_short)).to be_nil
      end
    end
  end

  describe '#nyan_frames' do
    it 'returns 12 frames' do
      frames = invoke_private(repl, :nyan_frames)
      expect(frames.size).to eq(12)
    end

    it 'each frame contains ANSI color codes' do
      frames = invoke_private(repl, :nyan_frames)
      frames.each do |frame|
        expect(frame).to include("\e[") # ANSI escape character
        expect(frame).to include('━')    # The bar character
      end
    end

    it 'has 7 unique frames (based on 7 rainbow colors)' do
      frames = invoke_private(repl, :nyan_frames)
      expect(frames.uniq.size).to eq(7)
    end
  end
end
