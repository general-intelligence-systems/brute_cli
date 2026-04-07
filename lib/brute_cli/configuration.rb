# frozen_string_literal: true

module BruteCLI
  Configuration = Struct.new(:spinner) do
    def initialize
      super
      self.spinner = BruteCLI::Spinner::Nyan
    end
  end

  def self.config
    @config ||= Configuration.new
  end
end
