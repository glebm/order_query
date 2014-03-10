$:.push File.expand_path('../lib', __FILE__)
require 'search_in_order/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name     = 'search_in_order'
  s.version  = SearchInOrder::VERSION
  s.author   = 'Gleb Mazovetskiy'
  s.email    = 'glex.spb@gmail.com'
  s.homepage = 'https://github.com/glebm/search_in_order'
  s.license  = 'MIT'
  s.summary  = 'ActiveRecord plugin that can find next / previous item(s) in 1 query.'

  s.files      = Dir['{app,lib,config}/**/*', 'MIT-LICENSE', 'Rakefile', 'Gemfile', 'README.md']
  s.test_files = Dir['test/**/*']

  s.add_dependency 'activerecord', '~> 4.0'
  s.add_dependency 'activesupport', '~> 4.0'
  s.add_development_dependency 'rspec'
end
