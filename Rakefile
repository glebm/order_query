begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc 'Test all Gemfiles from spec/*.gemfile'
task :test_all_gemfiles do
  require 'pty'
  require 'shellwords'
  cmd      = 'bundle --quiet && bundle exec rake --trace'
  statuses = Dir.glob('./spec/gemfiles/*{[!.lock]}').map do |gemfile|
    env = {'BUNDLE_GEMFILE' => gemfile}
    cmd_with_env = "  (#{env.map { |k, v| "export #{k}=#{Shellwords.escape v}" } * ' '}; #{cmd})"
    $stderr.puts "Testing\n#{cmd_with_env}"
    PTY.spawn(env, cmd) do |r, _w, pid|
      begin
        r.each_line { |l| puts l }
      rescue Errno::EIO
        # Errno:EIO error means that the process has finished giving output.
      ensure
        ::Process.wait pid
      end
    end
    [$? && $?.exitstatus == 0, cmd_with_env]
  end
  failed_cmds = statuses.reject(&:first).map { |(_status, cmd_with_env)| cmd_with_env }
  if failed_cmds.empty?
    $stderr.puts '✓ Tests pass with all gemfiles'
  else
    $stderr.puts "❌ FAILING (#{failed_cmds.size} / #{statuses.size})\n#{failed_cmds * "\n"}"
    exit 1
  end
end
