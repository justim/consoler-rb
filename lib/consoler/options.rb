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
    # @raise [RuntimeError] if you try to use a duplicate name
    def initialize(options_def)
      @options = []
      @description = nil

      return if options_def.nil?

      # strip the description
      if (match = /(^|\s+)-- (?<description>.*)$/.match(options_def))
        @description = match[:description]
        options_def = options_def[0...-match[0].size]
      end

      options = options_def.split ' '
      tracker = Consoler::OptionalsTracker.new

      option_names = []

      while (option_def = options.shift)
        Consoler::Option.create option_def, tracker do |option|
          raise "Duplicate option name: #{option.name}" if option_names.include? option.name

          option_names.push option.name

          option.aliases.each do |alias_|
            raise "Duplicate alias name: #{alias_.name}" if option_names.include? alias_.name

            option_names.push alias_.name
          end

          @options.push option
        end
      end
    end

    # Get a option by its name
    #
    # May be matched by one of its aliases
    #
    # @param name [String] Name of the option
    # @return [Consoler::Option, nil]
    def get(name)
      option, = get_with_alias name
      option
    end

    # Get a option by its name, with matched alias
    #
    # @param name [String] Name of the option
    # @return [[(Consoler::Option, nil), (Consoler::Option, nil)]]
    def get_with_alias(name)
      each do |option, _|
        if option.name == name
          return option, option
        end

        option.aliases.each do |alias_|
          return option, alias_ if alias_.name == name
        end
      end

      [nil, nil]
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

    # Get the definition for these options
    #
    # @return [String] Options definition
    def to_definition
      definition = ''
      optional = nil

      each do |option, i|
        definition += ' '

        if optional.nil? && option.is_optional
          definition += '['
          optional = option.is_optional
        end

        definition += option.to_definition

        # only close when the next option is not optional, or another optional group
        if option.is_optional && (@options[i + 1].nil? || optional != @options[i + 1].is_optional)
          definition += ']'
          optional = nil
        end
      end

      definition.strip
    end
  end

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
