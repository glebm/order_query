# -*- encoding : utf-8 -*-
# Configure Rails Environment
ENV['RAILS_ENV'] = ENV['RACK_ENV'] = 'test'
unless defined?(RUBY_ENGINE) && RUBY_ENGINE == 'rbx'
  begin
    require 'coveralls'
    Coveralls.wear! 'rails'
  rescue LoadError
    false
  end
end
require 'search_in_order'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
