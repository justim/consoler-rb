# frozen_string_literal: true

require_relative 'test_helper'
require 'consoler'

def with_captured_stdout
  old_stdout = $stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = old_stdout
end

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

    result = with_captured_stdout do
      app.run()
    end

    expected = <<-io
Consoler app

Usage:
  #{$0} jobs start [--force]  -- start the job
    io

    assert_equal expected, result
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
end
