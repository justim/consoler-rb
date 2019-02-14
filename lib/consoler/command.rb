# frozen_string_literal: true

module Consoler
  # Consoler command
  #
  # Basically a named hash
  #
  # @attr_reader [String] command Name of the command
  # @attr_reader [Consoler::Options] options List of all options
  # @attr_reader [Proc] action Action for this command
  class Command
    attr_reader :command
    attr_reader :options
    attr_reader :action

    # Create a command
    #
    # @param [Hash] options
    # @option options [String] :command Name of the command
    # @option options [Consoler::Options] :options List of all options
    # @option options [Proc] :action Action for this command
    def initialize(options)
      @command = options[:command]
      @options = options[:options]
      @action = options[:action]
    end
  end
end
