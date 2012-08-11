# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "secret_store/version"

Gem::Specification.new do |s|
  s.name        = "secret_store"
  s.version     = SecretStore::VERSION
  s.authors     = ["Brendon Murphy"]
  s.email       = ["xternal1+github@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Store secrets for your app in a encrypted in a yaml file.}
  s.description = s.summary

  s.rubyforge_project = "secret_store"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {spec}/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency "gibberish"

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
end
