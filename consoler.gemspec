# frozen_string_literal: true

require_relative 'lib/consoler/version'

Gem::Specification.new do |spec|
  spec.name          = 'consoler'
  spec.version       = Consoler::VERSION
  spec.date          = Time.now.strftime('%Y-%m-%d')
  spec.summary       = 'Consoler'
  spec.description   = 'Sinatra-like application builder for the console'
  spec.authors       = ['Tim']
  spec.email         = 'me@justim.net'
  spec.homepage      = 'https://github.com/justim/consoler-rb'

  spec.license       = 'MIT'
  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.platform      = Gem::Platform::RUBY
  spec.require_paths = ['lib']

  # build docs on install
  spec.metadata['yard.run'] = 'yri'

  spec.required_ruby_version = '>= 2.4'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'minitest', '~> 5.11.3'
  spec.add_development_dependency 'mutex_m', '~> 0.1.2'
  spec.add_development_dependency 'ostruct', '~> 0.1.0'
  spec.add_development_dependency 'rake', '~> 12.3.0'
  spec.add_development_dependency 'simplecov', '~> 0.16.1'
  spec.add_development_dependency 'yard', '~> 0.9.12'
end
