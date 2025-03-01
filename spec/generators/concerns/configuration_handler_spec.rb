require 'spec_helper'
require 'test_helper'

RSpec.describe Tenant::ConfigurationHandler do
  # Create a test class that includes the ConfigurationHandler module
  let(:test_class) do
    Class.new do
      include Tenant::ConfigurationHandler
      include Tenant::Logging
      
      attr_accessor :configuration, :rails_all_path
      
      def initialize(configuration = nil)
        @configuration = configuration
        @rails_all_path = Dir.mktmpdir('rails_generator_test')
      end
      
      def cleanup
        FileUtils.rm_rf(@rails_all_path) if @rails_all_path && File.directory?(@rails_all_path)
      end
    end
  end
  
  let(:configuration) { build(:application_configuration) }
  let(:handler) { test_class.new(configuration) }
  
  after do
    handler.cleanup
  end
  
  describe '#configure_database' do
    context 'with PostgreSQL configuration' do
      let(:configuration) { build(:application_configuration, :with_postgresql) }
      
      it 'configures PostgreSQL database' do
        # Create a mock database.yml file
        FileUtils.mkdir_p("#{handler.rails_all_path}/config")
        File.open("#{handler.rails_all_path}/config/database.yml", 'w') do |f|
          f.puts "development:"
          f.puts "  adapter: postgresql"
          f.puts "  database: app_development"
        end
        
        # Mock the system method to prevent actual command execution
        allow(handler).to receive(:system).and_return(true)
        
        handler.configure_database
        
        # Verify the database.yml file was updated
        database_yml = YAML.load_file("#{handler.rails_all_path}/config/database.yml")
        expect(database_yml['development']['username']).to eq('postgres')
        expect(database_yml['development']['password']).to eq('password')
      end
      
      it 'adds the pg gem to the configuration' do
        # Mock the system method to prevent actual command execution
        allow(handler).to receive(:system).and_return(true)
        
        # Create a mock database.yml file
        FileUtils.mkdir_p("#{handler.rails_all_path}/config")
        File.open("#{handler.rails_all_path}/config/database.yml", 'w') do |f|
          f.puts "development:"
          f.puts "  adapter: postgresql"
          f.puts "  database: app_development"
        end
        
        handler.configure_database
        
        # Verify the pg gem was added
        pg_gem = configuration.gems.find { |g| g.name == 'pg' }
        expect(pg_gem).not_to be_nil
      end
    end
    
    context 'with MySQL configuration' do
      let(:configuration) { build(:application_configuration, :with_mysql) }
      
      it 'configures MySQL database' do
        # Create a mock database.yml file
        FileUtils.mkdir_p("#{handler.rails_all_path}/config")
        File.open("#{handler.rails_all_path}/config/database.yml", 'w') do |f|
          f.puts "development:"
          f.puts "  adapter: mysql2"
          f.puts "  database: app_development"
        end
        
        # Mock the system method to prevent actual command execution
        allow(handler).to receive(:system).and_return(true)
        
        handler.configure_database
        
        # Verify the database.yml file was updated
        database_yml = YAML.load_file("#{handler.rails_all_path}/config/database.yml")
        expect(database_yml['development']['username']).to eq('root')
        expect(database_yml['development']['password']).to eq('password')
      end
      
      it 'adds the mysql2 gem to the configuration' do
        # Mock the system method to prevent actual command execution
        allow(handler).to receive(:system).and_return(true)
        
        # Create a mock database.yml file
        FileUtils.mkdir_p("#{handler.rails_all_path}/config")
        File.open("#{handler.rails_all_path}/config/database.yml", 'w') do |f|
          f.puts "development:"
          f.puts "  adapter: mysql2"
          f.puts "  database: app_development"
        end
        
        handler.configure_database
        
        # Verify the mysql2 gem was added
        mysql2_gem = configuration.gems.find { |g| g.name == 'mysql2' }
        expect(mysql2_gem).not_to be_nil
      end
    end
  end
  
  describe '#setup_search_engine' do
    context 'with Elasticsearch configuration' do
      let(:configuration) { build(:application_configuration, :with_elasticsearch) }
      
      it 'creates Elasticsearch initializer' do
        # Mock the system method to prevent actual command execution
        allow(handler).to receive(:system).and_return(true)
        allow(handler).to receive(:update_readme_with_env_vars).and_return(true)
        
        handler.setup_search_engine
        
        # Verify the Elasticsearch initializer was created
        initializer_path = "#{handler.rails_all_path}/config/initializers/elasticsearch.rb"
        expect(File.exist?(initializer_path)).to be true
        
        # Verify the content of the initializer
        initializer_content = File.read(initializer_path)
        expect(initializer_content).to include('Elasticsearch::Model.client')
        expect(initializer_content).to include('ENV[\'ELASTICSEARCH_URL\']')
      end
      
      it 'creates Searchable concern' do
        # Mock the system method to prevent actual command execution
        allow(handler).to receive(:system).and_return(true)
        allow(handler).to receive(:update_readme_with_env_vars).and_return(true)
        
        handler.setup_search_engine
        
        # Verify the Searchable concern was created
        concern_path = "#{handler.rails_all_path}/app/models/concerns/searchable.rb"
        expect(File.exist?(concern_path)).to be true
        
        # Verify the content of the concern
        concern_content = File.read(concern_path)
        expect(concern_content).to include('module Searchable')
        expect(concern_content).to include('include Elasticsearch::Model')
      end
    end
    
    context 'with MeiliSearch configuration' do
      let(:configuration) { build(:application_configuration, :with_meilisearch) }
      
      it 'creates MeiliSearch initializer' do
        # Mock the system method to prevent actual command execution
        allow(handler).to receive(:system).and_return(true)
        allow(handler).to receive(:update_readme_with_env_vars).and_return(true)
        
        handler.setup_search_engine
        
        # Verify the MeiliSearch initializer was created
        initializer_path = "#{handler.rails_all_path}/config/initializers/meilisearch.rb"
        expect(File.exist?(initializer_path)).to be true
        
        # Verify the content of the initializer
        initializer_content = File.read(initializer_path)
        expect(initializer_content).to include('MeiliSearch::Rails.configuration')
        expect(initializer_content).to include('ENV[\'MEILISEARCH_HOST\']')
      end
      
      it 'creates Searchable concern' do
        # Mock the system method to prevent actual command execution
        allow(handler).to receive(:system).and_return(true)
        allow(handler).to receive(:update_readme_with_env_vars).and_return(true)
        
        handler.setup_search_engine
        
        # Verify the Searchable concern was created
        concern_path = "#{handler.rails_all_path}/app/models/concerns/searchable.rb"
        expect(File.exist?(concern_path)).to be true
        
        # Verify the content of the concern
        concern_content = File.read(concern_path)
        expect(concern_content).to include('module Searchable')
        expect(concern_content).to include('searchkick')
      end
    end
  end
  
  describe '#load_configuration_from_yaml' do
    it 'loads configuration from YAML file' do
      # Create a test YAML file
      yaml_path = "#{handler.rails_all_path}/config.yml"
      FileUtils.mkdir_p(File.dirname(yaml_path))
      
      File.open(yaml_path, 'w') do |f|
        f.puts "frontend: react"
        f.puts "css_framework: tailwind"
        f.puts "database: postgresql"
        f.puts "database_options:"
        f.puts "  username: postgres"
        f.puts "  password: password"
        f.puts "search_engine: elasticsearch"
        f.puts "search_engine_options:"
        f.puts "  host: http://localhost:9200"
        f.puts "vector_db: pgvector"
        f.puts "vector_db_options:"
        f.puts "  dimensions: 1536"
        f.puts "embedding_provider: openai"
        f.puts "embedding_provider_options:"
        f.puts "  model: text-embedding-ada-002"
      end
      
      # Mock the log methods to prevent actual logging
      allow(handler).to receive(:log_info).and_return(true)
      
      handler.load_configuration_from_yaml(yaml_path)
      
      # Verify the configuration was loaded correctly
      expect(handler.configuration.frontend).to eq(:react)
      expect(handler.configuration.css_framework).to eq(:tailwind)
      expect(handler.configuration.database).to eq(:postgresql)
      expect(handler.configuration.database_options).to eq({ 'username' => 'postgres', 'password' => 'password' })
      expect(handler.configuration.search_engine).to eq(:elasticsearch)
      expect(handler.configuration.search_engine_options).to eq({ 'host' => 'http://localhost:9200' })
      expect(handler.configuration.vector_db).to eq(:pgvector)
      expect(handler.configuration.vector_db_options).to eq({ 'dimensions' => 1536 })
      expect(handler.configuration.embedding_provider).to eq(:openai)
      expect(handler.configuration.embedding_provider_options).to eq({ 'model' => 'text-embedding-ada-002' })
    end
  end
end 