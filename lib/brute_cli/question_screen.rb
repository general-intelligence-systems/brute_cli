# frozen_string_literal: true

require "bubbletea"
require "lipgloss"
require "bubbles"

module BruteCLI
  # Full-screen alternate-buffer question form built directly on Bubbletea.
  #
  # Opens a new terminal screen (like fzf/vim) via alt_screen: true,
  # renders select/multi-select forms with Lipgloss styling, handles
  # keyboard input through Bubbletea's raw-mode event loop (termios),
  # and restores the original screen when done.
  class QuestionScreen
    include Bubbletea::Model

    # ── Styles ──

    ACCENT     = "#FFCC00"
    DIM        = "#666666"
    SELECTED   = "#00FF88"
    HELP_COLOR = "#555555"

    # ── Public API ──

    def self.ask(questions)
      screen = new(questions)
      screen.run
    end

    def initialize(questions)
      @questions = questions.map { |q| normalize(q) }
      @question_idx = 0
      @cursor = 0
      @selected = Set.new         # for multi-select
      @answers = []               # collected answers per question
      @state = :selecting         # :selecting | :other_input | :done | :aborted
      @text_input = Bubbles::TextInput.new
      @text_input.prompt = "  > "
      @text_input.placeholder = "Type your response..."
      @width = 80
      @height = 24

      build_styles
    end

    def run
      # Release the terminal from reline before bubbletea takes over.
      # Reline may hold termios flags (cooked mode, echo, signal handling)
      # that prevent bubbletea's Go FFI from entering raw mode and reading
      # escape sequences (arrow keys). deprep_terminal restores the
      # terminal to its pre-reline state so bubbletea gets a clean slate.
      reline_active = defined?(Reline) && Reline.respond_to?(:deprep_terminal)
      Reline.deprep_terminal if reline_active

      Bubbletea.run(self, alt_screen: true)
      @state == :aborted ? @questions.map { [] } : @answers
    ensure
      # Re-prep reline so the REPL prompt works when we return.
      Reline.prep_terminal if reline_active
    end

    # ── Bubbletea::Model interface ──

    def init
      [self, nil]
    end

    def update(message)
      case message
      when Bubbletea::WindowSizeMessage
        @width = message.width
        @height = message.height
        [self, nil]
      when Bubbletea::KeyMessage
        handle_key(message)
      else
        [self, nil]
      end
    end

    def view
      return "" if @state == :done || @state == :aborted

      case @state
      when :selecting
        view_selecting
      when :other_input
        view_other_input
      else
        ""
      end
    end

    private

    # ── Key handling ──

    def handle_key(msg)
      case @state
      when :selecting
        handle_selecting_key(msg)
      when :other_input
        handle_other_input_key(msg)
      else
        [self, nil]
      end
    end

    def handle_selecting_key(msg)
      opts = current_options_with_other

      # Match on KeyMessage type methods first (reliable across Go FFI
      # versions), then fall back to string name for character keys.
      if msg.to_s == "ctrl+c" || msg.to_s == "q"
        @state = :aborted
        return [self, Bubbletea.quit]
      end

      if msg.up? || msg.to_s == "k"
        @cursor = (@cursor - 1) % opts.size
        return [self, nil]
      end

      if msg.down? || msg.to_s == "j"
        @cursor = (@cursor + 1) % opts.size
        return [self, nil]
      end

      if msg.space? || msg.to_s == "x"
        if current_multiple?
          if @selected.include?(@cursor)
            @selected.delete(@cursor)
          else
            @selected.add(@cursor)
          end
        end
        return [self, nil]
      end

      if msg.enter?
        return confirm_selection
      end

      [self, nil]
    end

    def handle_other_input_key(msg)
      if msg.enter?
        val = @text_input.value.strip
        current_answer = pending_selected_labels
        current_answer << val unless val.empty?
        return finalize_answer(current_answer)
      end

      if msg.esc?
        @state = :selecting
        return [self, nil]
      end

      if msg.to_s == "ctrl+c"
        @state = :aborted
        return [self, Bubbletea.quit]
      end

      @text_input, cmd = @text_input.update(msg)
      [self, cmd]
    end

    # ── Selection logic ──

    def confirm_selection
      opts = current_options_with_other

      if current_multiple?
        labels = @selected.sort.map { |i| opts[i] }
      else
        labels = [opts[@cursor]]
      end

      if labels.include?(:other)
        labels.delete(:other)
        @state = :other_input
        @text_input.value = ""
        @text_input.focus
        @pending_labels = labels.map { |l| l.is_a?(Hash) ? l[:value] : l }
        return [self, nil]
      end

      answer = labels.map { |l| l.is_a?(Hash) ? l[:value] : l.to_s }
      finalize_answer(answer)
    end

    def pending_selected_labels
      (@pending_labels || []).map(&:to_s)
    end

    def finalize_answer(answer)
      @answers << answer.map(&:to_s)

      # Advance to next question
      @question_idx += 1
      if @question_idx >= @questions.size
        @state = :done
        [self, Bubbletea.quit]
      else
        @cursor = 0
        @selected = Set.new
        @state = :selecting
        [self, nil]
      end
    end

    # ── View rendering ──

    def view_selecting
      q = current_question
      opts = current_options_with_other
      lines = []

      # Header
      lines << ""
      lines << @header_style.render("  #{q['header'] || 'Question'}")
      lines << ""

      # Question text
      lines << @question_style.render("  #{q['question']}")
      lines << ""

      # Options
      opts.each_with_index do |opt, i|
        is_cursor = i == @cursor
        label = opt == :other ? "Other (custom answer)" : "#{opt[:label]} -- #{opt[:desc]}"

        if current_multiple?
          check = @selected.include?(i) ? "[x]" : "[ ]"
          prefix = is_cursor ? " > #{check} " : "   #{check} "
        else
          prefix = is_cursor ? "  > " : "    "
        end

        text = "#{prefix}#{label}"
        lines << if is_cursor
          @cursor_style.render(text)
        else
          @option_style.render(text)
        end
      end

      # Help bar
      lines << ""
      help = if current_multiple?
        "  up/down navigate | space toggle | enter confirm | q quit"
      else
        "  up/down navigate | enter select | q quit"
      end
      lines << @help_style.render(help)

      # Progress
      if @questions.size > 1
        lines << @help_style.render("  question #{@question_idx + 1}/#{@questions.size}")
      end

      content = lines.join("\n")

      # Center vertically
      content_lines = content.split("\n").size
      pad = [(@height - content_lines) / 2, 1].max
      ("\n" * pad) + content
    end

    def view_other_input
      q = current_question
      lines = []

      lines << ""
      lines << @header_style.render("  #{q['header'] || 'Question'}")
      lines << ""
      lines << @question_style.render("  Your answer:")
      lines << ""
      lines << "  #{@text_input.view}"
      lines << ""
      lines << @help_style.render("  enter submit | esc back | ctrl+c quit")

      content = lines.join("\n")
      content_lines = content.split("\n").size
      pad = [(@height - content_lines) / 2, 1].max
      ("\n" * pad) + content
    end

    # ── Helpers ──

    def normalize(q)
      q.transform_keys(&:to_s).tap do |h|
        h["options"] = (h["options"] || []).map { |o| o.transform_keys(&:to_s) }
      end
    end

    def current_question
      @questions[@question_idx]
    end

    def current_multiple?
      current_question["multiple"]
    end

    def current_options_with_other
      opts = current_question["options"].map do |o|
        { label: o["label"], desc: o["description"], value: o["label"] }
      end
      opts << :other
      opts
    end

    def build_styles
      @header_style = Lipgloss::Style.new
        .bold(true)
        .foreground(ACCENT)

      @question_style = Lipgloss::Style.new
        .bold(true)

      @cursor_style = Lipgloss::Style.new
        .foreground(SELECTED)
        .bold(true)

      @option_style = Lipgloss::Style.new

      @help_style = Lipgloss::Style.new
        .foreground(HELP_COLOR)
        .italic(true)
    end
  end
end
