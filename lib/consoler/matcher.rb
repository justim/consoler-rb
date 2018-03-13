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

      loop_args do |arg|
        unless parse_options then
          @argument_values.push arg
          next
        end

        if arg == '--' then
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

      if @matched_options.size == @options.size then
        @matched_options['remaining'] = remaining
        return @matched_options
      end

      return nil
    end

    private

    def _analyze(arg)
      is_long = false
      is_short = false
      name = nil

      if arg[0..1] == '--' then
        is_long = true
        name = arg[2..-1]
      elsif arg[0] == '-' then
        is_short = true
        name = arg[1..-1]
      end

      if name.nil?
        @argument_values.push arg
        return true
      end

      unless name.nil? then
        option_name = if is_short then
                        name[0]
                      else
                        name
                      end

        option = @options.get option_name

        return nil if option.nil?

        needs_short = option.is_short
        needs_long = option.is_long

        if needs_long and not is_long then
          return nil
        elsif needs_short and not is_short then
          return nil
        end

        if is_long then
          if option.is_value then
            return nil if peek_next.nil?
            @matched_options[name] = peek_next
            skip
          else
            @matched_options[name] = true
          end
        end

        if is_short then
          if name.size == 1 and option.is_value then
            return nil if peek_next.nil?
            @matched_options[name] = peek_next
            skip
          else
            name.split('').each do |n|
              if @matched_options[n].nil? then
                @matched_options[n] = 0
              end

              @matched_options[n] += 1
            end
          end
        end
      end

      return true
    end

    def current
      @arguments.args[@index]
    end

    def peek_next
      @arguments.args[@index + 1]
    end

    def loop_args
      @index = 0
      size = @arguments.args.size

      while @index < size do
        yield current

        skip
      end
    end

    def skip
      @index += 1
    end

    def _match_arguments
      @optionals_before = {}
      @optionals_before_has_remaining = false

      argument_values_index = 0

      _match_arguments_optionals_before

      @optionals_before.each do |mandatory_arg_name, optionals|
        optionals.each do |_, optional|
          optional.each do |before|
            if before[:included] then
              @matched_options[before[:name]] = @argument_values[argument_values_index]
              argument_values_index += 1
            end
          end
        end

        if mandatory_arg_name != :REMAINING then
          @matched_options[mandatory_arg_name] = @argument_values[argument_values_index]
          argument_values_index += 1
        end
      end

      remaining = []

      while argument_values_index < @argument_values.size do
        remaining.push @argument_values[argument_values_index]
        argument_values_index += 1
      end

      remaining
    end

    def _match_arguments_optionals_before
      @optionals_before = {}
      tracker = {}

      @options.each do |option, key|
        next unless option.is_argument

        if option.is_optional then
          tracker[option.is_optional] = [] if tracker[option.is_optional].nil?

          tracker[option.is_optional].push({
            included: false,
            name: option.name,
          })
        else
          @optionals_before[option.name] = tracker
          tracker = {}
        end
      end

      if tracker != {} then
        @optionals_before[:REMAINING] = tracker
        @optionals_before_has_remaining = true
      end

      _match_arguments_optoins_before_matcher
    end

    def _match_arguments_optoins_before_matcher
      mandatories_matched = @optionals_before.size

      if @optionals_before_has_remaining then
        mandatories_matched -= 1
      end

      total = 0

      _each_optional_before_sorted do |before|
        if (total + before.size + mandatories_matched) <= @argument_values.size then
          total += before.size

          before.each do |val|
            val[:included] = true;
          end
        end
      end
    end

    def _fill_defaults
      @options.each do |option|
        if option.is_optional then
          unless @matched_options.has_key? option.name then
            @matched_options[option.name] = option.default_value
          end
        end
      end
    end

    def _each_optional_before_sorted
      @optionals_before.each do |_, optionals|
        tmp = []
        optionals.each do |optional_index, before|
          tmp.push({
            count: before.size,
            index: optional_index,
          })
        end

        tmp.sort! { |a, b| b[:count] - a[:count] }.each do |item|
          yield optionals[item[:index]]
        end
      end
    end
  end
end
