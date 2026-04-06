# frozen_string_literal: true

require 'gemoji'

module BruteCLI
  module Emoji
    def self.find(name)
      ::Emoji.find_by_alias(name)&.raw || ''
    end

    EYES       = find('eyes')
    PENCIL     = find('pencil2')
    PAGE       = find('page_facing_up')
    COMPUTER   = find('computer')
    SPARKLES   = find('sparkles')
    GLOBE      = find('globe_with_meridians')
    WASTEBASKET = find('wastebasket')
    REWIND     = find('rewind')
    DIAMOND    = find('diamond_shape_with_a_dot_inside')
    GEAR       = find('gear')
    MAG        = find('mag')
    HAMMER     = find('hammer_and_wrench')
    PACKAGE    = find('package')
    CLIPBOARD  = find('clipboard')
    CHECK      = find('white_check_mark')
    CROSS      = find('x')
    WRITING    = find('writing_hand')
    ROBOT      = find('robot')
    FOLDER     = find('file_folder')
  end
end
