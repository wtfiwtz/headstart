require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
  add_group 'Configuration', 'src/configuration'
  add_group 'Generators', 'src/generators'
  add_group 'Templates', 'templates'
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Run specs in random order to surface order dependencies
  config.order = :random
  Kernel.srand config.seed

  # Use expect syntax
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end 