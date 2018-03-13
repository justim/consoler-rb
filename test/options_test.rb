# frozen_string_literal: true

require_relative 'test_helper'
require 'consoler'

def check_option(option, desired)
  assert_equal desired[:name], option.name
  assert_equal desired[:is_argument] || false, option.is_argument
  assert_equal desired[:is_value] || false, option.is_value
  assert_equal desired[:is_short] || false, option.is_short
  assert_equal desired[:is_long] || false, option.is_long

  if desired[:is_optional].nil? then
    assert_nil option.is_optional
  else
    assert_equal desired[:is_optional], option.is_optional
  end
end

class OptionsTest < Minitest::Test
  def test_single_argument
    options = Consoler::Options.new 'name'

    assert_equal 1, options.size

    options.each do |option|
      check_option option, name: 'name', is_argument: true
    end
  end

  def test_single_short
    options = Consoler::Options.new '-f'

    assert_equal 1, options.size

    options.each do |option|
      check_option option, name: 'f', is_short: true
    end
  end

  def test_single_long
    options = Consoler::Options.new '--force'

    assert_equal 1, options.size

    options.each do |option|
      check_option option, name: 'force', is_long: true
    end
  end

  def test_single_short_value
    options = Consoler::Options.new '-f='

    assert_equal 1, options.size

    options.each do |option|
      check_option option, name: 'f', is_short: true, is_value: true
    end
  end

  def test_single_long_value
    options = Consoler::Options.new '--force='

    assert_equal 1, options.size

    options.each do |option|
      check_option option, name: 'force', is_long: true, is_value: true
    end
  end

  def test_single_optional_argument
    options = Consoler::Options.new '[name]'

    assert_equal 1, options.size

    options.each do |option|
      check_option option, name: 'name', is_argument: true, is_optional: 1
    end
  end

  def test_single_optional_short
    options = Consoler::Options.new '[-f]'

    assert_equal 1, options.size

    options.each do |option|
      check_option option, name: 'f', is_short: true, is_optional: 1
    end
  end

  def test_single_optional_long
    options = Consoler::Options.new '[--force]'

    assert_equal 1, options.size

    options.each do |option|
      check_option option, name: 'force', is_long: true, is_optional: 1
    end
  end

  def test_combined_short
    options = Consoler::Options.new '-ab'

    assert_equal 2, options.size

    option_a = options.get 'a'
    check_option option_a, name: 'a', is_short: true

    option_b = options.get 'b'
    check_option option_b, name: 'b', is_short: true
  end

  def test_combined_short_value
    options = Consoler::Options.new '-ab='

    assert_equal 2, options.size

    option_a = options.get 'a'
    check_option option_a, name: 'a', is_short: true

    option_b = options.get 'b'
    check_option option_b, name: 'b', is_short: true, is_value: true
  end

  def test_multi_argument
    options = Consoler::Options.new 'first_name last_name'

    assert_equal 2, options.size

    option_1 = options.get 'first_name'
    check_option option_1, name: 'first_name', is_argument: true

    option_2 = options.get 'last_name'
    check_option option_2, name: 'last_name', is_argument: true
  end

  def test_multi_optional_1
    options = Consoler::Options.new '[first_name] last_name'

    assert_equal 2, options.size

    option_1 = options.get 'first_name'
    check_option option_1, name: 'first_name', is_argument: true, is_optional: 1

    option_2 = options.get 'last_name'
    check_option option_2, name: 'last_name', is_argument: true
  end

  def test_multi_optional_2
    options = Consoler::Options.new 'first_name [last_name]'

    assert_equal 2, options.size

    option_1 = options.get 'first_name'
    check_option option_1, name: 'first_name', is_argument: true

    option_2 = options.get 'last_name'
    check_option option_2, name: 'last_name', is_argument: true, is_optional: 1
  end

  def test_multi_optional_3
    options = Consoler::Options.new '[first_name] [last_name]'

    assert_equal 2, options.size

    option_1 = options.get 'first_name'
    check_option option_1, name: 'first_name', is_argument: true, is_optional: 1

    option_2 = options.get 'last_name'
    check_option option_2, name: 'last_name', is_argument: true, is_optional: 2
  end

  def test_multi_optional_4
    options = Consoler::Options.new '[first_name last_name]'

    assert_equal 2, options.size

    option_1 = options.get 'first_name'
    check_option option_1, name: 'first_name', is_argument: true, is_optional: 1

    option_2 = options.get 'last_name'
    check_option option_2, name: 'last_name', is_argument: true, is_optional: 1
  end

  def test_combined_optional_short
    options = Consoler::Options.new '[-ab]'

    assert_equal 2, options.size

    option_a = options.get 'a'
    check_option option_a, name: 'a', is_short: true, is_optional: 1

    option_b = options.get 'a'
    check_option option_b, name: 'a', is_short: true, is_optional: 1
  end

  def test_description_1
    options = Consoler::Options.new '-- Command description'

    assert_equal 0, options.size
    assert_equal 'Command description', options.description
  end

  def test_description_2
    options = Consoler::Options.new 'name -- Command description'

    assert_equal 1, options.size
    assert_equal 'Command description', options.description

    options.each do |option|
      check_option option, name: 'name', is_argument: true
    end
  end

  def test_invalid_name
    err = assert_raises RuntimeError do
      Consoler::Options.new '-'
    end

    assert_equal 'Option must have a name', err.message
  end

  def test_invalid_short_long
    err = assert_raises RuntimeError do
      Consoler::Options.new '---force'
    end

    assert_equal 'Option can not be a long and a short option', err.message
  end

  def test_invalid_argument_value
    err = assert_raises RuntimeError do
      Consoler::Options.new 'name='
    end

    assert_equal 'Arguments can\'t have a value', err.message
  end

  def test_unopened_optional
    err = assert_raises RuntimeError do
      Consoler::Options.new 'name]'
    end

    assert_equal 'Unopened optional', err.message
  end

  def test_nested_optionals
    err = assert_raises RuntimeError do
      Consoler::Options.new '[first_name [last_name]]'
    end

    assert_equal 'Nested optionals are not allowed', err.message
  end

  def test_duplicate_name
    err = assert_raises RuntimeError do
      Consoler::Options.new 'name name'
    end

    assert_equal 'Duplicate option name: name', err.message
  end

  def test_definition_argument
    options = Consoler::Options.new 'name'

    assert_equal 'name', options.to_definition
  end

  def test_definition_short
    options = Consoler::Options.new '-n'

    assert_equal '-n', options.to_definition
  end

  def test_definition_short_combined
    options = Consoler::Options.new '-nf'

    # options get expanded
    assert_equal '-n -f', options.to_definition
  end

  def test_definition_short_combined_value
    options = Consoler::Options.new '-nf='

    # options get expanded
    assert_equal '-n -f=', options.to_definition
  end

  def test_definition_long
    options = Consoler::Options.new '--force'

    assert_equal '--force', options.to_definition
  end

  def test_definition_short_value
    options = Consoler::Options.new '-n='

    assert_equal '-n=', options.to_definition
  end

  def test_definition_long_value
    options = Consoler::Options.new '--name='

    assert_equal '--name=', options.to_definition
  end

  def test_definition_optional
    options = Consoler::Options.new '[name]'

    assert_equal '[name]', options.to_definition
  end

  def test_definition_optional_multi
    options = Consoler::Options.new '[first_name] [last_name]'

    assert_equal '[first_name] [last_name]', options.to_definition
  end

  def test_definition_optional_groups
    options = Consoler::Options.new '[first_name last_name]'

    assert_equal '[first_name last_name]', options.to_definition
  end

  def test_definition_mixed
    options = Consoler::Options.new '--force [name] [first_name last_name] -n='

    assert_equal '--force [name] [first_name last_name] -n=', options.to_definition
  end
end
