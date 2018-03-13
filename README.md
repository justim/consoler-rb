# Consoler

> Sinatra-like application builder for the console

## Usage

```ruby
# create a application
app = Consoler::Application.new description: 'A simple app'

# define a command
app.build 'target [--clean]' do |target, clean|
  # clean contains a boolean
  clean_up if clean

  # target contains a string
  build_project target
end
app.run(['build', 'production', '--clean'])

# this does not match, nothing is executed and the usage message is printed
app.run(['deploy', 'production'])
```

## Installation

```sh
gem install consoler
```

or add to your `Gemfile` for applications

```ruby
gem 'consoler', '~> 1.0.0'
```

or to your `.gemspec` file for gems

```ruby
Gem::Specification.new do |s|
  s.add_dependency 'consoler', '~> 1.0.0'
end
```
