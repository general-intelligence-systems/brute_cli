# frozen_string_literal: true

require "bundler/setup"
require "brute_cli"

module BruteCLI
  class REPL
    # A simple state-machine menu system powered by fzf.
    #
    # Each menu is a named bag of choices. Each choice points to either:
    #   - a Symbol  → the name of the next menu to show
    #   - nil       → exit the menu loop (Ctrl-C / Escape does the same)
    #   - anything else → returned to the caller as an "action" value
    #
    # The engine is just: while current.is_a?(Symbol) { current = show(menu) }
    #
    # Menus can be static (block evaluated at definition time) or dynamic
    # (block with arity > 0, evaluated fresh each time the menu is shown).
    #
    # Titles can be strings or callables (lambdas) for dynamic labels.
    #
    # Example:
    #
    #   app = BruteCLI::REPL::FzfMenu.new do
    #     menu :main, "Cool Menu" do
    #       choice "Status",  :status
    #       choice "Manage",  :manage
    #       choice "Exit",    nil
    #     end
    #   end
    #
    #   result = app.call          # starts at :main
    #   result = app.call(:models) # jump straight to :models
    #
    class FzfMenu
      class Menu
        attr_reader :title, :choices

        def initialize(title = nil)
          @title   = title
          @choices = []
        end

        def resolved_title
          @title.respond_to?(:call) ? @title.call : @title.to_s
        end

        def choice(label, target)
          @choices << [label, target]
        end
      end

      def initialize(&definition)
        @menus   = {}   # name → Menu (static)
        @dynamic = {}   # name → [title, block] (dynamic, built at render time)
        instance_eval(&definition) if definition
      end

      # Define a named menu.
      #
      # Static (block with no params — evaluated once at definition):
      #   menu :main, "Title" do
      #     choice "Foo", :foo
      #   end
      #
      # Dynamic (block with one param — evaluated each time the menu is shown):
      #   menu :models, "Title" do |m|
      #     m.choice "Foo", :foo
      #   end
      #
      def menu(name, title = nil, &block)
        if block.arity > 0
          @dynamic[name] = [title, block]
        else
          m = Menu.new(title)
          m.instance_eval(&block)
          @menus[name] = m
        end
      end

      # Run the menu loop starting at the given menu name.
      # Returns the final non-Symbol value chosen (or nil on escape/Ctrl-C).
      def call(start = nil)
        start ||= @menus.keys.first || @dynamic.keys.first
        current = start

        while current.is_a?(Symbol)
          current = show(resolve_menu(current))
        end

        current
      end

      # All registered menu names (static + dynamic).
      def menu_names
        @menus.keys | @dynamic.keys
      end

      private

      def resolve_menu(name)
        if @dynamic.key?(name)
          title, builder = @dynamic[name]
          m = Menu.new(title)
          builder.call(m)
          m
        else
          @menus.fetch(name) { raise KeyError, "Unknown menu: #{name.inspect}" }
        end
      end

      def show(menu)
        labels = menu.choices.map(&:first)
        return nil if labels.empty?

        selected = fzf(labels, prompt: menu.resolved_title)
        return nil unless selected

        menu.choices.detect { |label, _| label == selected }&.last
      end

      def fzf(items, prompt:)
        unless fzf_available?
          warn "fzf not found in PATH. Install fzf to use interactive menus."
          return nil
        end

        cmd = ["fzf", "--prompt=#{prompt} › ", "--height=~#{items.size + 2}", "--reverse", "--no-info"]
        IO.popen(cmd, "r+") do |io|
          io.puts items
          io.close_write
          io.gets&.strip
        end
      rescue Errno::ENOENT
        warn "fzf not found in PATH. Install fzf to use interactive menus."
        nil
      end

      def fzf_available?
        return @fzf_available if defined?(@fzf_available)
        @fzf_available = ENV["PATH"].to_s.split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, "fzf")) }
      end
    end
  end
end
