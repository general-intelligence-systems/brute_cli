# frozen_string_literal: true

RSpec.describe BruteCLI::Execution do
  let(:execution) { build_execution }

  describe '#model_short' do
    before do
      execution.instance_variable_set(:@model_name, model_name)
    end

    context 'with claude model' do
      let(:model_name) { 'claude-3.5-sonnet-20240620' }

      it 'strips claude- prefix and date suffix' do
        expect(execution.model_short).to eq('3.5-sonnet')
      end
    end

    context 'with non-claude model' do
      let(:model_name) { 'gpt-4-turbo' }

      it 'returns the full name' do
        expect(execution.model_short).to eq('gpt-4-turbo')
      end
    end

    context 'with nil model' do
      let(:model_name) { nil }

      it 'returns nil' do
        expect(execution.model_short).to be_nil
      end
    end
  end
end
