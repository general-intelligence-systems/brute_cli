# frozen_string_literal: true

require "test_helper"

class BruteCliTest < Minitest::Test
  def test_version
    refute_nil BruteCli::VERSION
  end
end
