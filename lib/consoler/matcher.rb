# frozen_string_literal: true

module Consoler
  # Argument/Options matcher
  #
  # Given a list of arguments and a list option try to match them
  class Matcher
    # Create a matcher
    #
    # @param [Consoler::Arguments] arguments List of arguments
    # @param [Consoler::Options] options List of options
    def initialize(arguments, options)
      @arguments = arguments
      @options = options

      @index = 0
      @matched_options = {}
      @argument_values = []
    end

    # Match arguments against options
    #
    # @return [Hash, nil] Matched information, or <tt>nil</tt> is returned when there was no match
    def match
      parse_options = true

      _loop_args do |arg|
        unless parse_options
          @argument_values.push arg
          next
        end

        # when "argument" is --, then stop parsing the rest of the arguments
        # and treat the rest as regular arguments
        if arg == '--'
          parse_options = false
          next
        end

        analyzed = _analyze arg

        if analyzed.nil?
          return nil
        end
      end

      remaining = _match_arguments
      _fill_defaults

      if @matched_options.size == @options.size
        @matched_options['remaining'] = remaining

        # make sure all aliases are also filled
        @options.each do |option|
          option.aliases.each do |alias_|
            @matched_options[alias_.name] = @matched_options[option.name]
          end
        end

        return @matched_options
      end

      nil
    end

    private

    # Analyze a single argument
    #
    # @param [String] arg Single argument
    # @return [true, nil] true on success, nil on failure
    def _analyze(arg)
      is_long = false
      is_short = false
      name = nil

      if arg[0..1] == '--'
        is_long = true
        name = arg[2..-1]
      elsif arg[0] == '-'
        is_short = true
        name = arg[1..-1]
      end

      # arg is not a long/short option, add to arguments values
      unless is_long || is_short
        @argument_values.push arg
        return true
      end

      unless name.nil?
        # get the name of the option, short options use the first character
        option_name = if is_short
                        name[0]
                      else
                        name
                      end

        option, matched = @options.get_with_alias option_name

        # no option by this name in options
        return nil if option.nil?

        # see if the type if right, short or long
        if matched.is_long && !is_long
          return nil
        elsif matched.is_short && !is_short
          return nil
        end

        if is_long
          if option.is_value
            # is_value needs a next argument for its value
            return nil if _peek_next.nil?

            @matched_options[option.name] = _peek_next
            _skip_next
          else
            option_value! option
          end
        end

        if is_short
          if name.size == 1 && option.is_value
            # is_value needs a next argument for its value
            return nil if _peek_next.nil?

            @matched_options[option.name] = _peek_next
            _skip_next
          else
            # for every character (short option) increment the option value
            name.split('').each do |n|
              short_option = @options.get n
              return nil if short_option.nil?

              option_value! short_option
            end
          end
        end
      end

      true
    end

    # Set the value of an option
    #
    # Long or short option needed
    #
    # @param [Consoler::Option]
    def option_value!(option)
      if option.is_short
        if @matched_options[option.name].nil?
          @matched_options[option.name] = 0
        end

        @matched_options[option.name] += 1
      else
        @matched_options[option.name] = true
      end
    end

    # Loop through the arguments
    #
    # @yield [String] An argument
    # @return [Consoler::Matcher]
    def _loop_args
      @index = 0
      size = @arguments.args.size

      # use an incrementing index, to be able to peek to the next in the list
      # and to skip an item
      while @index < size
        yield @arguments.args[@index]

        _skip_next
      end

      self
    end

    # Peek at the next argument
    #
    # Only useful inside {Consoler::Matcher#_loop_args}
    #
    # @return [String, nil]
    def _peek_next
      @arguments.args[@index + 1]
    end

    # Skip to the next argument
    #
    # Useful if you use a peeked argument
    #
    # @return [nil]
    # @return [Consoler::Matcher]
    def _skip_next
      @index += 1

      self
    end

    # Match arguments to defined option arguments
    #
    # @return [Array<String>, nil] The remaining args,
    #                              or <tt>nil</tt> if there are not enough arguments
    def _match_arguments
      @optionals_before = {}
      @optionals_before_has_remaining = false

      total_argument_values = @argument_values.size
      argument_values_index = 0

      _match_arguments_optionals_before

      @optionals_before.each do |mandatory_arg_name, optionals|
        # fill the optional argument option with a value if there are enough
        # arguments supplied (info available from optionals map)
        optionals.each do |_, optional|
          optional.each do |before|
            if before[:included]
              return nil if argument_values_index >= total_argument_values

              @matched_options[before[:name]] = @argument_values[argument_values_index]
              argument_values_index += 1
            end
          end
        end

        # only fill mandatory argument if its not the :REMAINING key
        if mandatory_arg_name != :REMAINING
          return nil if argument_values_index >= total_argument_values

          @matched_options[mandatory_arg_name] = @argument_values[argument_values_index]
          argument_values_index += 1
        end
      end

      remaining = []

      # left over arguments
      while argument_values_index < @argument_values.size
        remaining.push @argument_values[argument_values_index]
        argument_values_index += 1
      end

      remaining
    end

    # Create a map of all optionals and before which mandatory argument they appear
    #
    # @return [Consoler::Matcher]
    def _match_arguments_optionals_before
      @optionals_before = {}
      tracker = {}

      @options.each do |option, _key|
        next unless option.is_argument

        if option.is_optional
          # setup tracker for optional group
          tracker[option.is_optional] = [] if tracker[option.is_optional].nil?

          # mark all optionals as not-included
          tracker[option.is_optional].push(
            included: false,
            name: option.name,
          )
        else
          @optionals_before[option.name] = tracker
          tracker = {}
        end
      end

      # make sure all optionals are accounted for in the map
      if tracker != {}
        # use a special key so we can handle it differently in the filling process
        @optionals_before[:REMAINING] = tracker
        @optionals_before_has_remaining = true
      end

      _match_arguments_options_before_matcher

      self
    end

    # Match remaining args against the optionals map
    #
    # @return [Consoler::Matcher]
    def _match_arguments_options_before_matcher
      # number of arguments that are needed to fill our mandatory argument options
      mandatories_matched = @optionals_before.size

      # there are optionals at the end of the options, don't match the void
      if @optionals_before_has_remaining
        mandatories_matched -= 1
      end

      total = 0

      # loop through optional map
      _each_optional_before_sorted do |before|
        # are there enough arguments left to fill this optional group
        if (total + before.size + mandatories_matched) <= @argument_values.size
          total += before.size

          before.each do |val|
            val[:included] = true
          end
        end
      end

      self
    end

    # Give all unmatched optional options there default value
    #
    # @return [Consoler::Matcher]
    def _fill_defaults
      @options.each do |option|
        next unless option.is_optional

        unless @matched_options.key? option.name
          @matched_options[option.name] = option.default_value
        end
      end

      self
    end

    # Loop through the optionals before map
    #
    # Sorted by number of optionals in a group
    #
    # @return [Consoler::Matcher]
    def _each_optional_before_sorted
      @optionals_before.each do |_, optionals|
        tmp = []
        optionals.each do |optional_index, before|
          tmp.push(
            count: before.size,
            index: optional_index,
          )
        end

        tmp.sort! { |a, b| b[:count] - a[:count] }.each do |item|
          yield optionals[item[:index]]
        end
      end

      self
    end
  end
end
