# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] = ENV['RACK_ENV'] = 'test'
if ENV['COVERAGE'] && !%w[rbx jruby].include?(RUBY_ENGINE)
  require 'simplecov'
  SimpleCov.command_name 'RSpec'
end
require 'order_query'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

require 'fileutils'
FileUtils.mkpath 'log' unless File.directory? 'log'
ActiveRecord::Base.logger = Logger.new('log/test-queries.log')
adapter = ENV.fetch('DB', 'sqlite3')
case adapter
when 'mysql2', 'postgresql'
  system({ 'DB' => adapter }, 'script/create-db-users') unless ENV['TRAVIS']
  config = {
    # Host 127.0.0.1 required for default postgres installation on Ubuntu.
    host: '127.0.0.1',
    database: 'order_query_gem_test',
    encoding: 'utf8',
    min_messages: 'WARNING',
    adapter: adapter,
    username: ENV['DB_USERNAME'] || 'order_query',
    password: ENV['DB_PASSWORD'] || 'order_query'
  }
  ActiveRecord::Tasks::DatabaseTasks.create config.stringify_keys
  ActiveRecord::Base.establish_connection config
when 'sqlite3'
  ActiveRecord::Base.establish_connection adapter: adapter, database: ':memory:'
else
  fail "Unknown DB adapter #{adapter}. "\
       'Valid adapters are: mysql2, postgresql, sqlite3.'
end
