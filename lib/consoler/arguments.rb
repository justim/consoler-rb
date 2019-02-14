# frozen_string_literal: true

require_relative 'matcher'

module Consoler
  # Arguments
  #
  # @attr_reader [Array<String>] args Raw arguments
  class Arguments
    attr_reader :args

    def initialize(args)
      @args = args
    end

    # Match arguments against options
    #
    # @see Consoler::Matcher#match
    # @return [Hash, nil] Matched information, or <tt>nil</tt> is returned when there was no match
    def match(options)
      matcher = Consoler::Matcher.new self, options
      matcher.match
    end
  end
end
