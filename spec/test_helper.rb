require 'fileutils'
require 'yaml'
require 'factory_bot'
require 'faker'
require 'webmock/rspec'
require 'vcr'

# Load the application code
$LOAD_PATH.unshift File.expand_path('../src', __dir__)
Dir[File.expand_path('../src/**/*.rb', __dir__)].sort.each { |f| require f }

# Configure VCR
VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data('<API_KEY>') { ENV['API_KEY'] }
end

# Configure FactoryBot
FactoryBot.find_definitions

# Test utilities
module TestUtils
  # Create a temporary directory for testing
  def self.create_temp_dir
    temp_dir = File.join(Dir.tmpdir, "rails_generator_test_#{Time.now.to_i}")
    FileUtils.mkdir_p(temp_dir)
    temp_dir
  end

  # Clean up temporary directory
  def self.cleanup_temp_dir(dir)
    FileUtils.rm_rf(dir) if dir && File.directory?(dir)
  end

  # Create a test YAML configuration
  def self.create_test_config(options = {})
    config = Tenant::Configuration::ApplicationConfiguration.new
    
    # Set basic configuration
    config.frontend = options[:frontend] || :mvc
    config.css_framework = options[:css_framework] || :bootstrap
    config.controller_inheritance = options.key?(:controller_inheritance) ? options[:controller_inheritance] : true
    config.form_builder = options[:form_builder] || :default
    
    # Set database configuration
    if options[:database]
      config.set_database(options[:database], options[:database_options] || {})
    end
    
    # Set search engine configuration
    if options[:search_engine]
      config.enable_search_engine(options[:search_engine], options[:search_engine_options] || {})
    end
    
    # Set vector database configuration
    if options[:vector_db]
      config.enable_vector_db(options[:vector_db], options[:vector_db_options] || {})
    end
    
    # Set embedding provider configuration
    if options[:embedding_provider]
      config.set_embedding_provider(options[:embedding_provider], options[:embedding_provider_options] || {})
    end
    
    # Add gems
    if options[:gems]
      options[:gems].each do |gem_info|
        config.add_gem(gem_info[:name], gem_info[:version], gem_info[:options] || {})
      end
    end
    
    # Add features
    if options[:authentication]
      config.enable_authentication(
        options[:authentication][:provider] || :devise,
        options[:authentication][:options] || {}
      )
    end
    
    if options[:file_upload]
      config.enable_file_upload(
        options[:file_upload][:provider] || :active_storage,
        options[:file_upload][:options] || {}
      )
    end
    
    if options[:background_jobs]
      config.enable_background_jobs(
        options[:background_jobs][:provider] || :sidekiq,
        options[:background_jobs][:options] || {}
      )
    end
    
    config
  end

  # Create test models
  def self.create_test_models
    [
      OpenStruct.new(
        name: 'User',
        attributes: [
          OpenStruct.new(name: 'email', type: 'string'),
          OpenStruct.new(name: 'name', type: 'string'),
          OpenStruct.new(name: 'password_digest', type: 'string'),
          OpenStruct.new(name: 'admin', type: 'boolean')
        ],
        associations: [
          OpenStruct.new(kind: 'has_many', name: 'posts', attrs: { dependent: :destroy }),
          OpenStruct.new(kind: 'has_one', name: 'profile', attrs: { dependent: :destroy })
        ]
      ),
      OpenStruct.new(
        name: 'Post',
        attributes: [
          OpenStruct.new(name: 'title', type: 'string'),
          OpenStruct.new(name: 'content', type: 'text'),
          OpenStruct.new(name: 'published', type: 'boolean')
        ],
        associations: [
          OpenStruct.new(kind: 'belongs_to', name: 'user'),
          OpenStruct.new(kind: 'has_many', name: 'comments', attrs: { dependent: :destroy })
        ]
      ),
      OpenStruct.new(
        name: 'Profile',
        attributes: [
          OpenStruct.new(name: 'bio', type: 'text'),
          OpenStruct.new(name: 'avatar', type: 'string')
        ],
        associations: [
          OpenStruct.new(kind: 'belongs_to', name: 'user')
        ]
      )
    ]
  end
end

# RSpec configuration
RSpec.configure do |config|
  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods
  
  # Clean up temporary directories after tests
  config.after(:each) do
    if @temp_dir && File.directory?(@temp_dir)
      TestUtils.cleanup_temp_dir(@temp_dir)
    end
  end
end 