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
  spec.required_ruby_version = '>= 3.2'

  spec.files         = Dir['lib/**/*.rb', 'exe/*']
  spec.bindir        = 'exe'
  spec.executables   = ['brute']
  spec.require_paths = ['lib']

  spec.add_dependency 'brute', '~> 0.1'
  spec.add_dependency 'brute_flow', '~> 0.1'
  spec.add_dependency 'gemoji', '~> 4.1'
  spec.add_dependency 'glamour', '~> 0.2'
  spec.add_dependency 'lipgloss', '~> 0.2'
  spec.add_dependency 'tty-spinner', '~> 0.9'
end
