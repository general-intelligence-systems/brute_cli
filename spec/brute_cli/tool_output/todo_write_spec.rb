# frozen_string_literal: true

RSpec.describe BruteCLI::ToolOutput::TodoWrite do
  def build_output(args: {}, result: nil)
    call = BruteCLI::Phase::ToolCall.new(name: 'todo_write', arguments: args)
    call.result = result if result
    described_class.new(call, width: 80).to_s
  end

  it 'uses the CLIPBOARD emoji' do
    expect(described_class::ICON).to eq(BruteCLI::Emoji::CLIPBOARD)
  end

  it 'renders todo list from args with status emojis' do
    output = build_output(
      args: {
        'todos' => [
          { 'id' => '1', 'content' => 'Fix the bug', 'status' => 'completed' },
          { 'id' => '2', 'content' => 'Write tests', 'status' => 'pending' },
          { 'id' => '3', 'content' => 'Deploy', 'status' => 'in_progress' },
        ]
      },
      result: { success: true, count: 3 }
    )

    expect(output).to include(BruteCLI::Emoji::CHECK)
    expect(output).to include('Fix the bug')
    expect(output).to include(BruteCLI::Emoji::SQUARE)
    expect(output).to include('Write tests')
    expect(output).to include(BruteCLI::Emoji::ARROWS)
    expect(output).to include('Deploy')
  end

  it 'handles symbol keys in todos' do
    output = build_output(
      args: {
        todos: [
          { id: '1', content: 'Symbol keys', status: 'pending' },
        ]
      },
      result: { success: true }
    )
    expect(output).to include('Symbol keys')
  end

  it 'falls back to square emoji for unknown status' do
    output = build_output(
      args: {
        'todos' => [
          { 'id' => '1', 'content' => 'Weird', 'status' => 'banana' },
        ]
      },
      result: { success: true }
    )
    expect(output).to include(BruteCLI::Emoji::SQUARE)
  end
end
