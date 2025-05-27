require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc 'Run all tests'
task test: :spec

desc 'Run tests for invalid files'
task :test_invalid do
  sh 'bundle exec rspec spec/invalid_file_spec.rb'
end

desc 'Run tests for basic commands'
task :test_basic do
  sh 'bundle exec rspec spec/basic_commands_spec.rb'
end

desc 'Run tests for tag read/write operations'
task :test_tag_read_write do
  sh 'bundle exec rspec spec/tag_read_write_spec.rb'
end
