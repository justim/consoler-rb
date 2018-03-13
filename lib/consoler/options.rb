# frozen_string_literal: true

require_relative 'option'

module Consoler

  # List of options
  #
  # @attr_reader [String] description Description of the options
  class Options
    attr_reader :description

    # Create a list of option based on a string definition
    #
    # @param options_def [String] A string definition of the desired options
    def initialize(options_def)
      @options = []
      @description = nil

      return if options_def.nil?

      if match = /(^|\s+)-- (?<description>.*)$/.match(options_def) then
        @description = match[:description]
        options_def = options_def[0...-match[0].size]
      end

      options = options_def.split ' '
      tracker = Consoler::OptionalsTracker.new

      option_names = []

      while option_def = options.shift do
        Consoler::Option.create option_def, tracker do |option|
          raise "Duplicate option name: #{option.name}" if option_names.include? option.name

          @options.push option
          option_names.push option.name
        end
      end
    end

    # Get a options by its name
    #
    # @param name [String] Name of the option
    # @return [Consoler::Option, nil]
    def get(name)
      each do |option|
        if option.name == name then
          return option
        end
      end

      return nil
    end

    # Loop through all options
    #
    # @yield [Consoler::Option, Integer] An option
    # @return [Consoler::Options]
    def each
      @options.each_with_index do |option, i|
        yield option, i
      end

      self
    end

    # Get the number of options
    #
    # @return [Integer]
    def size
      @options.size
    end

    def to_definition
      definition = ''
      optional = nil

      each do |option, i|
        definition += ' '

        if optional.nil? and option.is_optional then
          definition += '['
          optional = option.is_optional
        end

        definition += option.to_definition

        if option.is_optional then
          if @options[i + 1].nil? or optional != @options[i + 1].is_optional then
            definition += ']'
            optional = nil
          end
        end
      end

      definition.strip
    end
  end

  private

  # Optionals tracker
  #
  # @attr [Boolean] is_tracking Is inside optional options
  # @attr [Integer] index Optional group
  class OptionalsTracker
    attr_accessor :is_tracking
    attr_accessor :index

    # Create an optionals tracker
    def initialize
      @is_tracking = nil
      @index = 0
    end
  end
end
