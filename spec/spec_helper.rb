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
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
