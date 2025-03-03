# frozen_string_literal: true

module Consoler
  # Represents an option
  #
  # @attr_reader [String] name Name of the options
  # @attr_reader [Boolean] is_long Is the option long (<tt>--option</tt>)
  # @attr_reader [Boolean] is_short Is the option short (<tt>-o</tt>)
  # @attr_reader [Boolean] is_argument Is the option an argument
  # @attr_reader [Boolean] is_value Does the option need a value (<tt>--option=</tt>)
  # @attr_reader [Integer] is_optional Is the option optional (> 0) (<tt>[option]</tt>)
  # @attr_reader [Array] aliases List of aliases of option (<tt>-v|--verbose</tt>)
  class Option
    attr_reader :name
    attr_reader :is_long
    attr_reader :is_short
    attr_reader :is_argument
    attr_reader :is_value
    attr_reader :is_optional
    attr_reader :aliases

    # Create a option
    #
    # Yields an option for every option detected
    #
    # @param option_def [String] Definition of the option
    # @param tracker [Consoler::OptionalsTracker] optionals tracker
    def self.create(option_def, tracker)
      option = Option.new option_def, tracker

      # split short options with more than 1 char in multiple options
      if option.is_short && option.name.size > 1
        # remember state
        old_tracking = tracker.is_tracking
        old_is_value = option.is_value

        # if the complete option is optional, fake the tracker
        if option.is_optional
          tracker.is_tracking = true
        end

        names = option.name.split('')

        names.each_with_index do |name, i|
          new_name = "-#{name}"

          # if the short option should have a value, this only counts for the last option
          if old_is_value && i == names.count - 1
            new_name = "#{new_name}="
          end

          yield Option.new new_name, tracker
        end

        # reset to saved state
        tracker.is_tracking = old_tracking
      else
        yield option
      end
    end

    # Get the definition of the option
    #
    # Does not include the optional information, as that is linked to other
    # options
    #
    # @return [String]
    def to_definition
      definition = name

      if is_long
        definition = "--#{definition}"
      elsif is_short
        definition = "-#{definition}"
      end

      if is_value
        definition = "#{definition}="
      elsif is_argument
        definition = "<#{definition}>"
      end

      aliases.each do |alias_|
        definition = "#{definition}|#{alias_.to_definition}"
      end

      definition
    end

    # Get the default value of this option
    #
    # @return [nil | 0 | false]
    def default_value
      return nil if is_value
      return 0 if is_short
      return false if is_long

      nil
    end

    protected

    # Create a option
    #
    # @param [String] option_def Definition of the option
    # @param [Consoler::Tracker] tracker tracker
    # @raise [RuntimeError] if the option name is empty
    # @raise [RuntimeError] if the option is long _and_ short
    def initialize(option_def, tracker)
      # Check for multiple attributes in the option definition till we got the
      # final name and all of its attributes

      # make sure we don't wrongly process any alias
      alias_defs = option_def.split '|'
      option = alias_defs.shift || ''

      option, @is_optional = _is_optional option, tracker
      option, @is_long = _is_long option
      option, @is_short = _is_short option
      @is_argument = !@is_long && !@is_short
      option, @is_value = _value option, @is_argument
      option, @aliases = _aliases option, alias_defs, tracker

      if option[0] == '<'
        raise 'Invalid <, missing >' if option[-1] != '>'
        raise 'Only arguments support <, > around name' unless @is_argument

        option = option[1..-2]
      end

      raise 'Missing starting <' if option[-1] == '>'

      @name = option

      if @name.empty?
        raise 'Option must have a name'
      end

      if @is_long && @is_short
        raise 'Option can not be a long and a short option'
      end
    end

    private

    # Check optional definition
    #
    # Does it open an optional group
    # Does it close an optional group (can be both)
    # Updates the tracker
    # Removes leading [ and trailing ]
    #
    # @param [String] option Option definition
    # @param [Consoler::Tracker] tracker Optional tracker
    # @raise [RuntimeError] if you try to nest optional groups
    # @raise [RuntimeError] if you try to close an unopened optional
    # @return [(String, Integer|nil)] Remaining option definition, and, optional group if available
    def _is_optional(option, tracker)
      if option[0] == '['
        if !tracker.is_tracking
          # mark tracker as tracking
          tracker.is_tracking = true
          tracker.index += 1
          option = option[1..-1]
        else
          raise 'Nested optionals are not allowed'
        end
      end

      # get optional group index from tracking, if tracking
      optional = if tracker.is_tracking
                   tracker.index
                 end

      if option[-1] == ']'
        if tracker.is_tracking
          # mark tracker as non-tracking
          tracker.is_tracking = false
          option = option[0..-2]
        else
          raise 'Unopened optional'
        end
      end

      [option, optional]
    end

    # Check long definition
    #
    # @param [String] option Option definition
    # @return [(String, Boolean)]
    def _is_long(option)
      if option[0..1] == '--'
        long = true
        option = option[2..-1]
      else
        long = false
      end

      [option, long]
    end

    # Check short definition
    #
    # @param [String] option Option definition
    # @return [(String, Boolean)]
    def _is_short(option)
      if option[0] == '-'
        short = true
        option = option[1..-1]
      else
        short = false
      end

      [option, short]
    end

    # Check value definition
    #
    # @param [String] option Option definition
    # @raise [RuntimeError] if you try to assign a value to an argument
    # @return [(String, Boolean)]
    def _value(option, argument)
      if option[-1] == '='
        if argument
          raise 'Arguments can\'t have a value'
        end

        value = true
        option = option[0..-2]
      else
        value = false
      end

      [option, value]
    end

    # Parse all possible aliases
    #
    # @param [String] option Option definition
    # @param [Consoler::Tracker] tracker Optional tracker
    # @raise [RuntimeError] On all kinds of occasions
    # @return [(String, Array)] Remaining option definition, and, aliases if available
    def _aliases(option, alias_defs, tracker)
      return option, [] if alias_defs.empty?

      raise 'Argument can\'t have aliases' if is_argument
      raise 'Aliases are not allowed for multiple short options' if is_short && option.size > 1

      aliases_ = []
      alias_names = []

      while (alias_def = alias_defs.shift)
        Consoler::Option.create alias_def, tracker do |alias_|
          raise "Duplicate alias name: #{alias_.name}" if alias_names.include? alias_.name
          raise "Alias must have a value: #{alias_.name}" if is_value && !alias_.is_value
          raise "Alias can't have a value: #{alias_.name}" if !is_value && alias_.is_value

          aliases_.push alias_
          alias_names.push alias_.name
        end
      end

      [option, aliases_]
    end
  end
end
