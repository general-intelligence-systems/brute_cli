# frozen_string_literal: true

require "dry/cli"

module BruteCLI
  module CLI
    module Commands
      class Sessions < Dry::CLI::Command
        desc "List saved sessions"

        def call(**)
          sessions = Execution.list_sessions

          if sessions.empty?
            puts "No saved sessions."
            return
          end

          sessions.each do |s|
            age = format_age(s[:mtime])
            puts "#{s[:id]}  #{age}"
          end
        end

        private

        def format_age(time)
          delta = Time.now - time
          case delta
          when 0...60       then "#{delta.to_i}s ago"
          when 60...3600    then "#{(delta / 60).to_i}m ago"
          when 3600...86400 then "#{(delta / 3600).to_i}h ago"
          else                   "#{(delta / 86400).to_i}d ago"
          end
        end
      end
    end
  end
end
