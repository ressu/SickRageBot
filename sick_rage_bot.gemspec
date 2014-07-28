# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sick_rage_bot/version'

Gem::Specification.new do |spec|
  spec.name          = "sick_rage_bot"
  spec.version       = SickRageBot::VERSION
  spec.authors       = ["None"]
  spec.email         = ["nobody@example.com"]
  spec.summary       = %q(Bot to ease users on #SickRage in FreeNode)
  spec.description   = %q{Simple bot to ease the pain of the users in IRC}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end
