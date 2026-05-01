# Getting Started

This guide walks you through installing brute_cli and running your first prompt.

## Installation

```sh
gem install brute_cli
```

Or in a Gemfile:

```ruby
gem "brute_cli"
```

## Setup

Set an API key for your LLM provider:

```sh
export ANTHROPIC_API_KEY=sk-ant-...
# or
export OPENAI_API_KEY=sk-...
# or
export GOOGLE_API_KEY=AI...
```

## Single Prompt

```sh
brute "Fix the failing tests in spec/models/user_spec.rb"
```

## Options

```
Usage: brute [options] [prompt]
    -d, --directory DIR    Working directory
    -s, --session ID       Resume a session by ID
        --list-sessions    List saved sessions
    -v, --version          Show version
    -h, --help             Show help
```

## Debug Mode

Show backtraces on errors:

```sh
BRUTE_DEBUG=1 brute "do something"
```
