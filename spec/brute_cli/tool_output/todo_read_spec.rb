# frozen_string_literal: true

RSpec.describe BruteCLI::ToolOutput::TodoRead do
  def build_output(args: {}, result: nil)
    call = BruteCLI::Phase::ToolCall.new(name: 'todo_read', arguments: args)
    call.result = result if result
    described_class.new(call, width: 80).to_s
  end

  it 'uses the CLIPBOARD emoji' do
    expect(described_class::ICON).to eq(BruteCLI::Emoji::CLIPBOARD)
  end

  it 'renders todo list from result' do
    result = {
      todos: [
        { 'id' => '1', 'content' => 'Task A', 'status' => 'completed' },
        { 'id' => '2', 'content' => 'Task B', 'status' => 'cancelled' },
      ]
    }

    output = build_output(result: result)

    expect(output).to include(BruteCLI::Emoji::CHECK)
    expect(output).to include('Task A')
    expect(output).to include(BruteCLI::Emoji::CROSS)
    expect(output).to include('Task B')
  end
end
