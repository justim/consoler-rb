# Consoler [![Build Status](https://api.travis-ci.org/justim/consoler-rb.svg?branch=master)](https://travis-ci.org/justim/consoler-rb) [![Gem Version](https://badge.fury.io/rb/consoler.svg)](https://badge.fury.io/rb/consoler)

> Sinatra-like application builder for the console

## Quick usage

```ruby
# create an application
app = Consoler::Application.new description: 'A simple app'

# define a command
app.build '[--clean] <output_dir>' do |clean, output_dir|
  # clean contains a boolean
  clean_up if clean

  # output_dir contains a string
  build_project output_dir
end

# run with own args
app.run ['build', 'production', '--clean']

# this does not match, nothing is executed and the usage message is printed
app.run ['deploy', 'production']

# defaults to ARGV
app.run
```

## Features

- No fiddling with `ARGV` and friends
- Arguments filled based on their name, for easy access
- Grouped optionals
- Easy option aliasing

## Requirements

Tests are run against multiple ruby versions (latest supported):

- `2.4.x`
- `2.5.x`
- `2.6.x`
- `2.7.x`
- `3.0.x`

No other requirements exist.

## Installation

```sh
gem install consoler
```

or add to your `Gemfile` for applications

```ruby
gem 'consoler', '~> 1.2.0'
```

or to your `.gemspec` file for gems

```ruby
Gem::Specification.new do |spec|
  spec.add_dependency 'consoler', '~> 1.2.0'
end
```

## Docs

Full API documentation can the found here: https://www.rubydoc.info/gems/consoler/1.2.0

### API

#### Creating an application

```ruby
# create an application
app = Consoler::Application.new

# .. or with a description that will show up in the usage message
app = Consoler::Application.new description: 'A simple app'
```

#### Adding commands

All actions you want to create must have a command name, there is no top-level matching available at this point.

```ruby
# create an application
app = Consoler::Application.new

# in the most simple way, you provide a name (the method name) and a block you
# want to execute if it matches
app.build do
  # your code here
end

# to add options to your command, provide a options definition as an argument
app.build '[--clean] [--env=] [-v|--verbose] <output_dir>' do |clean, env, verbose, output_dir|
  # parameters are matched based on name
  # `clean` contains a boolean
  # `env` contains a string or nil if not provided
  # `verbose` contains a number, counting the times it occurred in the arguments
  # `output_dir` contains a string, if needed to match this command
end
```

#### Running the application

```ruby
# filename: app.rb

# create an application
app = Consoler::Application.new

# a build command
app.build '[--clean] [--env=] [-v|--verbose] <output_dir>' do |clean, env, verbose, output_dir|
  puts 'Starting build...' if verbose > 0

  do_clean_up if clean

  do_build env || 'development', output_dir

  puts 'Build complete' if verbose > 0
end

# a deploy command
app.build '[-v|--verbose] [--env=]' do |env|
  puts 'Starting deploy...' if verbose > 0

  do_deploy env || 'development'

  puts 'Deploy complete' if verbose > 0
end
```

_Shell commands:_
```sh
# start a build
ruby app.rb build --env production dist

# deploy
ruby app.rb deploy --verbose

# or, you can use command shortcuts. this works by prefix matching and only if
# there is one match, exact matches always have priority
ruby app.rb b --env production dist
ruby app.rb d --verbose

```

#### Options definition

| Option          | Meaning                         | Example                                |
| --------------- | ------------------------------- | -------------------------------------- |
| `-f`            | Short option with name `f`      | `ruby app.rb build -f`                 |
| `--clean`       | Long option with name `clean`   | `ruby app.rb build --clean`            |
| `-v\|--verbose` | Alias option for `v`            | `ruby app.rb build --verbose`          |
| `<output_dir>`  | Argument with name `output_dir` | `ruby app.rb build dist/`              |
| `--env=`        | Long option with value          | `ruby app.rb build --env production`   |
| `-e=`           | Short option with value         | `ruby app.rb build -e production`      |
| `[ .. ]`        | Optional options/arguments      | `ruby app.rb build` would match `[-v]` |

Some notes about these options:

- The `<`, `>` around the argument name a optional, but are always shown in de usage message for better legibility
- Optional-tokens can occur anywhere in the options, as long as they are not nested and properly closed. You can group optional parts, meaning that both options/arguments should be available or both not.
- Options and/or arguments are mandatory unless specified otherwise.
- Aliases should be the same "type", meaning that if the original option expands an value, the alias must do as well
- Aliases are only allowed for short and long options, with or without value and can be optional, just like regular options

Grouping of optionals allows you do things like this:

```ruby
app = Consoler::Application.new
app.shout '[<first_name> <last_name>] [<name>]' do |first_name, last_name, name|
  # by definition, `last_name` is also filled
  unless first_name.nil? then
    puts "Hello #{first_name} #{last_name}!"
  end

  unless name.nil? then
    puts "Hello #{name}!"
  end
end

# calling with two arguments can fill the first group
# prints "Hello John Doe!"
app.run ['shout', 'John', 'Doe']

# calling with one argument it is not possible to fill the first group
# prints "Hello Mr. White!"
app.run ['shout', 'Mr. White!']
```

#### Return types in action block

| Option type | Return type (ex.)       | Default (if optional) |
| ----------- | ----------------------- | --------------------- |
| Short       | `Integer` (`1`)         | `0`                   |
| Long        | `Boolean` (`true`)      | `false`               |
| Value       | `String` (`production`) | `nil`                 |
| Argument    | `String` (`dist/`)      | `nil`                 |

Aliased keep the properties as the original options; with a definition of `-v|--verbose` and providing `--verbose` as an argument, both `v` and `verbose` contain a number (`1` in this case). Same goes the other way around; with a definition of `--force|-f` and providing `-f` as an argument, both `force` and `f` contain a boolean (`true` in this case).

#### Subapplications

To make application nesting possible you can provide a complete application to a command, instead of an action block.

```ruby
# filename: app.rb

# create a subapplication
android = Consoler::Application.new
android.build do; end

# options are supported just like regular apps
android.clean '--force|-f' do; end

# create an application
app = Consoler::Application.new

# mount the android application on top of the android command
# note that the command does not support options
app.android android
```

You can now run the next bit to run the android build command:

```sh
ruby app.rb android build
```

You can build them as complicated as you like :)

### Complete example

```ruby
#!/usr/bin/env ruby

db = Consoler::Application.new
db.migrate '-- run all pending migrations' do
  run_migrate
end

db.rollback '[--migrations=] -- rollback a number of migrations' do |migrations|
  run_rollback migrations || 1
end

cache = Consoler::Application.new
cache.clear '[--env=] -- clear the cache for a given environment' do |env|
  run_cache_clear env || 'development'
end

cache.warmup '[--env=] -- warmup the cache for a given environment' do |env|
  run_cache_warmup env || 'development'
end

app = Consoler::Application.new
app.db db
app.cache cache

app.build '[--clean] [--env=] [-v] <output_dir> -- build the project' do |clean, env, v, output_dir|
  puts 'Starting build...' if v > 0

  if clean
    puts 'Starting clean...' if v > 1
    do_clean_up if clean
  end

  do_build env || 'development', output_dir

  puts 'Build complete' if v > 0
end
```

Make the file executable with `chmod a+x app.rb`, you can now call it with `./app.rb` without `ruby` in front of it, saves a couple keystrokes.

```sh
# run all migration
./app.rb db migrate
# rollback the last 4 migrations
./app.rb db rollback 4
# clean production cache
./app.rb cache clear --env production
# build the project, including cleaning and logging
./app.rb build --clean --env production -vv dist/
# print the usage message
./app.rb
```

## Final notes

If you like what you see, feel free to use it anyway you like. Also, don't hold back if you have suggestions/question and create an issue to let me know, and we can talk about it. And if you don't like what you see, PRs are welcome. You should probably file an issue first to make sure it's something worth doing, and the right way to do it.
