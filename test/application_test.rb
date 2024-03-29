# frozen_string_literal: true

require_relative 'test_helper'
require_relative './../lib/consoler'

class ApplicationTest < Minitest::Test
  def test_simple_app
    app = Consoler::Application.new
    app.remove '--force' do |force|
      assert_equal true, force
      true
    end

    result = app.run(['remove', '--force'])
    assert_equal true, result
  end

  def test_simple_subapp
    subapp = Consoler::Application.new
    subapp.start do; true; end

    app = Consoler::Application.new
    app.jobs subapp

    result = app.run(['jobs', 'start'])

    assert_equal true, result
  end

  def test_simple_app_no_match
    app = Consoler::Application.new
    app.remove do; true; end

    result = app.run(['add'], true)
    assert_nil result
  end

  def test_usage_message
    subapp = Consoler::Application.new
    subapp.start '[--force] -- start the job' do; true; end

    app = Consoler::Application.new description: 'Consoler app'
    app.jobs subapp

    expected = <<-io
Consoler app

Usage:
  #{$0} jobs start [--force]  -- start the job
    io

    assert_output expected do
      app.run
    end
  end

  def test_invalid_options
    err = assert_raises RuntimeError do
      app = Consoler::Application.new
      app.remove 1 do; end
    end

    assert_equal 'Invalid options', err.message
  end

  def test_invalid_action_1
    err = assert_raises RuntimeError do
      app = Consoler::Application.new
      app.remove 1
    end

    assert_equal 'Invalid subapp/block', err.message
  end

  def test_no_side_effects
    app = Consoler::Application.new
    app.build do
      true
    end

    args = ['build']
    result = app.run args

    assert_equal true, result
    assert_equal ['build'], args
  end

  def test_dashed_option
    app = Consoler::Application.new
    app.build '--use-fall' do |use_fall|
      use_fall
    end

    result = app.run ['build', '--use-fall']

    assert_equal true, result
  end

  def test_dashed_option_alias
    command_ran = false

    app = Consoler::Application.new
    app.build '--clear-cache|-c' do |clear_cache|
      command_ran = true
      clear_cache
    end

    result = app.run ['build', '--clear-cache']

    assert_equal true, result
    assert_equal true, command_ran
  end

  def test_subapp_dashed_alias
    command_ran = false

    db = Consoler::Application.new
    db.diff '--clear-cache|-c' do |clear_cache|
      command_ran = true
      clear_cache
    end

    app = Consoler::Application.new
    app.db db

    result = app.run ['db', 'diff', '--clear-cache']

    assert_equal true, result
    assert_equal true, command_ran
  end

  def test_respond_to_missing
    app = Consoler::Application.new
    assert_equal true, app.respond_to?(:hello)
  end

  def test_command_shortcut
    app = Consoler::Application.new
    app.cache do
      'cache'
    end

    result = app.run ['c']

    assert_equal 'cache', result
  end

  def test_command_shortcut_ambiguity
    app = Consoler::Application.new
    app.cache do 'cache'; end
    app.chase do 'chase'; end

    result = app.run ['c'], true

    assert_nil result
  end

  def test_command_shortcut_with_priority
    app = Consoler::Application.new
    app.cache do 'cache'; end
    app.c do 'c'; end

    result = app.run ['c']

    assert_equal 'c', result
  end

  def test_command_shortcut_with_subapp
    cache = Consoler::Application.new
    cache.clear do 'clear'; end

    app = Consoler::Application.new
    app.cache cache

    result = app.run ['c', 'c']

    assert_equal 'clear', result
  end

  def test_raised_error
    app = Consoler::Application.new
    app.invalid do raise 'Some error'; end

    expected = <<-io
A runtime error occured: Some error
    io

    assert_output nil, expected do
      app.run ['invalid']
    end
  end

  def test_nonrescued_raised_error
    app = Consoler::Application.new rescue_errors: false
    app.invalid do raise 'Some error'; end

    err = assert_raises RuntimeError do
      app.run ['invalid']
    end

    assert_equal 'Some error', err.message
  end
end
