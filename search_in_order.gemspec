$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "search_in_order/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "search_in_order"
  s.version     = SearchInOrder::VERSION
  s.authors     = ["TODO: Your name"]
  s.email       = ["TODO: Your email"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of SearchInOrder."
  s.description = "TODO: Description of SearchInOrder."

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "activerecord", '~> 4.0'
  s.add_dependency 'activesupport', '~> 4.0'
  s.add_development_dependency 'rails', '>= 4.0.3', '< 5'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'rspec-rails'
end
