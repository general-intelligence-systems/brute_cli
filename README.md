# 🚀 brute_cli 🔥

Command-line interface for the [Brute](../brute) coding agent. 🤖✨

## 💎 Installation

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

## Usage

### Single prompt

```sh
brute "Fix the failing tests in spec/models/user_spec.rb"
```

### Interactive mode

```sh
brute
brute> Add input validation to the signup form
brute> Now write tests for it
brute> exit
```

### Piped input

```sh
echo "Refactor the database connection pool" | brute
cat instructions.txt | brute
git diff HEAD~1 | brute "Review this diff for bugs"
```

### Set working directory

```sh
brute -d ~/projects/myapp "Upgrade the Rails version to 7.2"
```

### Sessions

Resume a previous conversation:

```sh
brute --list-sessions
#   a1b2c3d4...  (untitled)  2025-04-05T10:30:00+00:00

brute --session a1b2c3d4
```

### Debug mode

Show backtraces on errors:

```sh
BRUTE_DEBUG=1 brute "do something"
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

## Examples

### Fix a bug

```sh
brute "The login endpoint returns 500 when the email contains a plus sign. Find and fix it."
```

### Add a feature

```sh
brute "Add a rate limiter middleware to the API. Use Redis with a sliding window of 100 requests per minute per IP."
```

### Refactor

```sh
brute "Extract the payment processing logic from OrdersController into a PaymentService class"
```

### Run tests and fix failures

```sh
brute "Run the test suite with 'bundle exec rspec' and fix any failures"
```

### Code review

```sh
git diff main | brute "Review this diff. Flag bugs, security issues, and style problems."
```

### Explore a codebase

```sh
brute -d ~/projects/unfamiliar-repo "Explain how authentication works in this project"
```

### Multi-step task

```sh
brute "Add a /health endpoint that returns JSON with the app version, database status, and redis status. Write tests. Run them to make sure they pass."
```

## Dependencies

- [brute](../brute) — core agent library
- [brute_flow](../brute_flow) — BPMN flow engine (optional, loaded if available)
