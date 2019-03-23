# frozen_string_literal: true

require_relative 'options'
require_relative 'arguments'

module Consoler
  # Consoler application
  #
  # @example A simple application
  #   # create a application
  #   app = Consoler::Application.new description: 'A simple app'
  #
  #   # define a command
  #   app.build 'target [--clean]' do |target, clean|
  #     # clean contains a boolean
  #     clean_up if clean
  #
  #     # target contains a string
  #     build_project target
  #   end
  #   app.run(['build', 'production', '--clean'])
  #
  #   # this does not match, nothing is executed and the usage message is printed
  #   app.run(['deploy', 'production'])
  class Application
    # Create a consoler application
    #
    # @param options [Hash] Options for the application
    # @option options [String] :description The description for the application (optional)
    def initialize(options = {})
      @description = options[:description]
      @commands = []
    end

    # Accept all method_missing call
    #
    # We use the name as a command name, thus we accept all names
    #
    # @param _method_name [String] Name of the method
    # @param _include_private [bool] Name of the method
    def respond_to_missing?(_method_name, _include_private = false)
      true
    end

    # Register a command for this app
    #
    # @param command_name [Symbol] Name of the command
    # @param input [String, Consoler::Application] Options definition or a complete subapp
    # @yield [...] Executed when the action is matched with parameters based on your options
    # @return [nil]
    def method_missing(command_name, input = nil, &block)
      action = nil
      options_def = ''

      unless block.nil?
        action = block
        options_def = input

        if !options_def.nil? && !options_def.instance_of?(String)
          raise 'Invalid options'
        end
      end

      if input.instance_of? Consoler::Application
        action = input
        options_def = ''
      end

      if action.nil?
        raise 'Invalid subapp/block'
      end

      command = command_name.to_s

      _add_command(command, options_def, action)

      nil
    end

    # Run the application with a list of arguments
    #
    # @param args [Array] Arguments
    # @param disable_usage_message [Boolean] Disable the usage message when nothing it matched
    # @return [mixed] Result of your matched command, <tt>nil</tt> otherwise
    def run(args = ARGV, disable_usage_message = false)
      # TODO: signal handling of some kind?

      result, matched = _run(args.dup)

      if !matched && !disable_usage_message
        usage
      end

      result
    end

    # Show the usage message
    #
    # Contains all commands and options, including subapps
    def usage
      puts "#{@description}\n\n" unless @description.nil?
      puts 'Usage:'

      _commands_usage $PROGRAM_NAME
    end

    protected

    # Run the app
    #
    # @param [Array<String>] args Arguments
    # @return [(mixed, Boolean)] Result of the command, and, did the args match a command at all
    def _run(args)
      arg = args.shift

      return [nil, false] if arg.nil?

      arguments = Consoler::Arguments.new args
      exact_matches = []
      partial_matches = []

      @commands.each do |command|
        if command.command == arg
          exact_matches.push command
        elsif command.command.start_with? arg
          partial_matches.push command
        end
      end

      # we only allow a single partial match to prevent ambiguity
      partial_match = if partial_matches.size == 1
                        partial_matches[0]
                      end

      unless exact_matches.empty? && partial_match.nil?
        matches = exact_matches
        matches.push partial_match unless partial_match.nil?

        matches.each do |command|
          # the matched command contains a subapp, run subapp with the same
          # arguments (excluding the arg that matched this command)
          if command.action.instance_of?(Consoler::Application)
            result, matched = command.action._run(args)

            if matched
              return result, true
            end
          else
            match = arguments.match command.options

            next if match.nil?

            return _dispatch(command.action, match), true
          end
        end
      end

      [nil, false]
    end

    # Print the usage message for this command
    #
    # @param [String] prefix A prefix for the command from a parent app
    # @return [Consoler::Application]
    def _commands_usage(prefix = '')
      @commands.each do |command|
        # print the usage message of a subapp with a prefix from the current command
        if command.action.instance_of?(Consoler::Application)
          command.action._commands_usage "#{prefix} #{command.command}"
        else
          print "  #{prefix} #{command.command}"

          if command.options.size
            print " #{command.options.to_definition}"
          end

          unless command.options.description.nil?
            print "  -- #{command.options.description}"
          end

          print "\n"
        end
      end

      self
    end

    private

    # Add a command
    #
    # @param [String] command Command name
    # @param [String] options_def Definition of options
    # @param [Proc, Consoler::Application] action Action or subapp
    # @return [Consoler::Application]
    def _add_command(command, options_def, action)
      @commands.push(
        Consoler::Command.new(
          command: command,
          options: Consoler::Options.new(options_def),
          action: action,
        )
      )

      self
    end

    # Execute an action with argument match info
    #
    # @param [Proc] action Action
    # @param [Hash] match Argument match information
    def _dispatch(action, match)
      # match parameter names to indices of match information
      arguments = action.parameters.map do |parameter|
        parameter_name = parameter[1].to_s

        if match.key? parameter_name
          match[parameter_name]
        else
          # check for the normalized name of every match to see
          # if it fits the parameter name
          match.each do |name, value|
            normalized_name = _normalize name

            if parameter_name == normalized_name
              break value
            end
          end
        end
      end

      action.call(*arguments)
    end

    # Normalize a name to be used as a variable name
    #
    # @param [String] name Name
    # @return [String] Normalized name
    def _normalize(name)
      # maybe do something more, maybe not.. ruby does allow for
      # some weird stuff to be used as a variable name. the user
      # should use some common sense. and, other things might
      # also be an syntax error, like starting with a number.
      # this normalization is more of a comvenience than anything
      # else
      name.tr('-', '_')
    end
  end
end
