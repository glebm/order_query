# frozen_string_literal: true
SimpleCov.start do
  add_filter '/spec/'
  add_filter '.bundle/'
  add_group 'lib', 'lib/'
  formatter SimpleCov::Formatter::HTMLFormatter unless ENV['TRAVIS']
end
