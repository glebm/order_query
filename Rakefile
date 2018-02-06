# frozen_string_literal: true

begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

task default: :spec

# rubocop:disable Metrics/BlockLength,Style/StderrPuts

desc 'Test all Gemfiles from spec/*.gemfile'
task :test_all_gemfiles do
  require 'pty'
  require 'shellwords'
  cmd      = 'bundle install --quiet && bundle exec rake --trace'
  statuses = Dir.glob('./spec/gemfiles/*{[!.lock]}').map do |gemfile|
    Bundler.with_clean_env do
      env = { 'BUNDLE_GEMFILE' => gemfile }
      $stderr.puts "Testing #{File.basename(gemfile)}:
  export #{env.map { |k, v| "#{k}=#{Shellwords.escape v}" } * ' '}; #{cmd}"
      PTY.spawn(env, cmd) do |r, _w, pid|
        begin
          r.each_line { |l| puts l }
        rescue Errno::EIO # rubocop:disable Lint/HandleExceptions
          # Errno:EIO error means that the process has finished giving output.
        ensure
          ::Process.wait pid
        end
      end
      [$CHILD_STATUS&.exitstatus&.zero?, gemfile]
    end
  end
  failed_gemfiles = statuses.reject(&:first).map { |(_, gemfile)| gemfile }
  if failed_gemfiles.empty?
    $stderr.puts "✓ Tests pass with all #{statuses.size} gemfiles"
  else
    $stderr.puts "❌ FAILING (#{failed_gemfiles.size} / #{statuses.size})
#{failed_gemfiles * "\n"}"
    exit 1
  end
end

# rubocop:enable Metrics/BlockLength,Style/StderrPuts
