# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'suo/version'

Gem::Specification.new do |spec|
  spec.name          = "suo"
  spec.version       = Suo::VERSION
  spec.authors       = ["Nick Elser"]
  spec.email         = ["nick.elser@gmail.com"]

  spec.summary       = %q(Distributed semaphores using Memcached or Redis.)
  # spec.description   = %q{TODO: Long description}
  spec.homepage      = "https://github.com/nickelser/suo"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "dalli"
  spec.add_dependency "redis"
  spec.add_dependency "msgpack"

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rubocop", "~> 0.30.0"
end
