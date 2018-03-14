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
    def initialize(options={})
      @description = options[:description]
      @commands = []
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

      unless block.nil? then
        action = block
        options_def = input

        if not options_def.nil? and not options_def.instance_of? String then
          raise 'Invalid options'
        end
      end

      if input.instance_of? Consoler::Application then
        action = input
        options_def = ''
      end

      if action.nil? then
        raise 'Invalid subapp/block'
      end

      command = command_name.to_s

      _add_command(command, options_def, action)

      return nil
    end

    # Run the application with a list of arguments
    #
    # @param args [Array] Arguments
    # @param disable_usage_message [Boolean] Disable the usage message when nothing it matched
    # @return [mixed] Result of your matched command, <tt>nil</tt> otherwise
    def run(args = ARGV, disable_usage_message = false)
      # TODO signal handling of some kind?

      result, matched = _run(args.dup)

      if not matched and not disable_usage_message
        usage
      end

      return result
    end

    # Show the usage message
    #
    # Contains all commands and options, including subapps
    def usage
      puts "#{@description}\n\n" unless @description.nil?
      puts 'Usage:'

      _commands_usage $0
    end

    protected

    def _run(args)
      arg = args.shift
      arguments = Consoler::Arguments.new args

      @commands.each do |command|
        if command.command == arg then
          if command.action.instance_of? Consoler::Application then
            result, matched = command.action._run(args)

            if matched then
              return result, true
            end
          else
            match = arguments.match command.options

            next if match.nil?

            return _dispatch(command.action, match), true
          end
        end
      end

      return nil, false
    end

    def _commands_usage(prefix='')
      @commands.each do |command|
        if command.action.instance_of? Consoler::Application then
          command.action._commands_usage "#{prefix} #{command.command}"
        else
          print "  #{prefix} #{command.command}"

          if command.options.size then
            print " #{command.options.to_definition}"
          end

          unless command.options.description.nil? then
            print "  -- #{command.options.description}"
          end

          print "\n"
        end
      end
    end

    private

    def _add_command(command, options_def, action)
      @commands.push(Consoler::Command.new(
        command: command,
        options: Consoler::Options.new(options_def),
        action: action,
      ))
    end

    def _dispatch(action, match)
      arguments = action.parameters.map do |parameter|
        match[parameter[1].to_s]
      end

      action.call(*arguments)
    end
  end
end
