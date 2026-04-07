# frozen_string_literal: true

require 'gemoji'

module BruteCLI
  module Emoji
    def self.💩(name)
      ::Emoji.find_by_alias(name)&.raw || ''
    end

    # brutal mate...

    EYES        = 💩 'eyes'
    PENCIL      = 💩 'pencil2'
    PAGE        = 💩 'page_facing_up'
    COMPUTER    = 💩 'computer'
    SPARKLES    = 💩 'sparkles'
    GLOBE       = 💩 'globe_with_meridians'
    WASTEBASKET = 💩 'wastebasket'
    REWIND      = 💩 'rewind'
    DIAMOND     = 💩 'diamond_shape_with_a_dot_inside'
    GEAR        = 💩 'gear'
    MAG         = 💩 'mag'
    HAMMER      = 💩 'hammer_and_wrench'
    PACKAGE     = 💩 'package'
    CLIPBOARD   = 💩 'clipboard'
    CHECK       = 💩 'white_check_mark'
    CROSS       = 💩 'x'
    WRITING     = 💩 'writing_hand'
    ROBOT       = 💩 'robot'
    FOLDER      = 💩 'file_folder'
    SQUARE      = 💩 'white_large_square'
    ARROWS      = 💩 'arrows_counterclockwise'
    SMOKE       = 💩 'dash'
  end
end
