# frozen_string_literal: true

require_relative 'lib/brute_cli/version'

Gem::Specification.new do |spec|
  spec.name          = 'brute_cli'
  spec.version       = BruteCli::VERSION
  spec.authors       = ['Brute Contributors']
  spec.summary       = 'CLI for the Brute coding agent'
  spec.description   = 'Interactive command-line interface for the Brute coding agent. ' \
                        'Supports single-prompt, interactive, piped, and session modes.'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.0'

  spec.files         = Dir['lib/**/*.rb', 'exe/*']
  spec.bindir        = 'exe'
  spec.executables   = ['brute']
  spec.require_paths = ['lib']

  spec.add_dependency 'brute', '~> 2.0'
  # brute_flow is optional and loaded with rescue LoadError in brute_cli.rb
  spec.add_dependency 'gemoji', '~> 4.1'
  spec.add_dependency 'colorize', '~> 1.1'
  spec.add_dependency 'reline', '~> 0.5'
  spec.add_dependency 'tty-markdown', '~> 0.7'
  spec.add_dependency 'tty-screen', '~> 0.8'
  spec.add_dependency 'bubbletea', '~> 0.1'
  spec.add_dependency 'dry-cli'
  spec.add_dependency 'lipgloss', '~> 0.2'
  spec.add_dependency 'bubbles', '~> 0.1'
  spec.add_dependency 'tty-spinner', '~> 0.9'

end
