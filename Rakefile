require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
end

namespace :test do
  desc 'Run all tests'
  task :all => :spec

  desc 'Run configuration tests'
  task :configuration do
    sh 'bundle exec rspec spec/configuration'
  end

  desc 'Run generator tests'
  task :generators do
    sh 'bundle exec rspec spec/generators'
  end

  desc 'Run with code coverage'
  task :coverage do
    ENV['COVERAGE'] = 'true'
    Rake::Task['spec'].invoke
  end
end

task :default => 'test:all' 