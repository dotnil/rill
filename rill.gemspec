require 'rubygems'

Gem::Specification.new do |s|
  s.name          = 'rill'
  s.version       = '0.1.10'
  s.executables   << 'rill'
  s.date          = '2013-06-08'
  s.summary       = 'SeaJS Bundler in Ruby'
  s.description   = 'A simple CMD module bundler'
  s.authors       = ['Jake Chen']
  s.email         = 'jakeplus@gmail.com'
  s.files         = Dir['lib/**/*.rb', 'bin/*.rb']
  s.require_paths = ['lib']
  s.homepage      = 'http://rubygems.org/gems/rill'
end
