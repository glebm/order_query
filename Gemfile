source 'https://rubygems.org'

gemspec

group :test, :development do
  gem 'coveralls', require: false
end

platform :mri, :rbx do
  # version locked because of rbx issue, see https://github.com/travis-ci/travis-ci/issues/2006#issuecomment-36275141
  gem 'sqlite3', '=1.3.8'
end

platform :jruby do
  gem 'activerecord-jdbcsqlite3-adapter'
end
