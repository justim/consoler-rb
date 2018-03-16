# frozen_string_literal: true

require_relative 'test_helper'
require 'consoler'

def run_match(args, options_def)
  arguments = Consoler::Arguments.new args
  options = Consoler::Options.new options_def

  arguments.match options
end

class ArgumentsTest < Minitest::Test
  def test_single_argument
    match = run_match ['John'], 'name'

    assert_equal 'John', match['name']
  end

  def test_skip_parsing
    match = run_match ['--', '--hello'], 'name'

    assert_equal '--hello', match['name']
  end

  def test_single_short
    match = run_match ['-f'], '-f'

    assert_equal 1, match['f']
  end

  def test_single_long
    match = run_match ['--force'], '--force'

    assert_equal true, match['force']
  end

  def test_single_short_mismatch
    match = run_match ['--f'], '-f'

    assert_nil match
  end

  def test_single_long_mismatch
    match = run_match ['-f'], '--f'

    assert_nil match
  end

  def test_single_short_value
    match = run_match ['-n', '19'], '-n='

    assert_equal '19', match['n']
  end

  def test_single_long_value
    match = run_match ['--name', 'John'], '--name='

    assert_equal 'John', match['name']
  end

  def test_single_short_optional
    match = run_match [], '[-n]'

    assert_equal 0, match['n']
  end

  def test_single_long_optional
    match = run_match [], '[--force]'

    assert_equal false, match['force']
  end

  def test_single_argument_optional
    match = run_match [], '[name]'

    assert_nil match['name']
  end

  def test_single_short_value_optional
    match = run_match [], '[-n=]'

    assert_nil match['n']
  end

  def test_single_long_value_optional
    match = run_match [], '[--name=]'

    assert_nil match['name']
  end

  def test_multi_argument_optional
    match = run_match ['Doe'], '[first_name] last_name'

    assert_nil match['first_name']
    assert_equal 'Doe', match['last_name']
  end

  def test_multi_argument_grouped_optional_1
    match = run_match ['John'], '[first_name last_name]'

    assert_nil match['first_name']
    assert_nil match['last_name']
  end

  def test_multi_argument_grouped_optional_2
    match = run_match ['John'], '[first_name last_name] [name]'

    assert_nil match['first_name']
    assert_nil match['last_name']
    assert_equal 'John', match['name']
  end

  def test_multi_argument_grouped_optional_3
		match = run_match(
      ['1', '2', '3', '4'],
      '[first] [second thirth] fourth [fifth] [sixth] seventh',
    )

    assert_nil match['first']
    assert_equal '1', match['second']
    assert_equal '2', match['thirth']
    assert_equal '3', match['fourth']
    assert_nil match['fifth']
    assert_nil match['sixth']
    assert_equal '4', match['seventh']
  end

  def test_value_argument
    match = run_match(
      ['--reason', 'no more', 'hello.rb'],
      '--reason= filename'
    )

    assert_equal 'no more', match['reason']
    assert_equal 'hello.rb', match['filename']
  end

  def test_multi_short
    match = run_match ['-vv', '-v'], '-v'

    assert_equal 3, match['v']
  end

  def test_multi_short_mixed
    match = run_match ['-vvf', '-v'], '-vf'

    assert_equal 3, match['v']
    assert_equal 1, match['f']
  end

  def test_dashed_long_option
    match = run_match ['--dashed-option'], '--dashed-option'

    assert_equal true, match['dashed-option']
  end

  def test_party_deluxe
		match = run_match(
      ['-vv', '-v', '--reason', 'no more', 'hello.rb', 'something'],
      '[-v] [-f] [--lang] [--reason=] [foo bar] filename -- yay!',
    )

    assert_equal 3, match['v']
    assert_equal 0, match['f']
    assert_equal false, match['lang']
    assert_equal 'no more', match['reason']
    assert_nil match['foo']
    assert_nil match['bar']
    assert_equal 'hello.rb', match['filename']
    assert_equal 'something', match['remaining'][0]
  end
end
