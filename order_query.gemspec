# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'order_query/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name = 'order_query'
  s.version = OrderQuery::VERSION
  s.author = 'Gleb Mazovetskiy'
  s.email = 'glex.spb@gmail.com'
  s.homepage = 'https://github.com/glebm/order_query'
  s.license = 'MIT'
  s.summary = 'Find next / previous Active Record(s) in one query'
  s.description = 'Find next / previous Active Record(s) in one efficient query'
  s.files = Dir[
      '{app,lib,config}/**/*', 'MIT-LICENSE', 'Rakefile', 'Gemfile', '*.md']
  s.test_files = Dir['spec/**/*']

  if s.respond_to?(:metadata=)
    s.metadata = { 'issue_tracker' => 'https://github.com/glebm/order_query' }
  end

  s.required_ruby_version = '>= 2.3.0'

  s.add_dependency 'activerecord', '>= 5.0', '< 7.1'
  s.add_dependency 'activesupport', '>= 5.0', '< 7.1'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rspec', '~> 3.4'
  s.add_development_dependency 'simplecov'
end
