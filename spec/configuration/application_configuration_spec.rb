require 'spec_helper'
require 'test_helper'

RSpec.describe Tenant::Configuration::ApplicationConfiguration do
  describe 'initialization' do
    it 'initializes with default values' do
      config = described_class.new
      
      expect(config.frontend).to eq(:mvc)
      expect(config.css_framework).to eq(:bootstrap)
      expect(config.controller_inheritance).to be true
      expect(config.form_builder).to eq(:default)
      expect(config.database).to eq(:sqlite)
      expect(config.vector_db).to be_nil
      expect(config.embedding_provider).to be_nil
      expect(config.gems).to be_empty
      expect(config.features).to be_empty
      expect(config.monitoring).to be_empty
    end
  end
  
  describe '#add_gem' do
    it 'adds a gem to the configuration' do
      config = described_class.new
      config.add_gem('rails', '~> 7.0')
      
      expect(config.gems.length).to eq(1)
      expect(config.gems.first.name).to eq('rails')
      expect(config.gems.first.version).to eq('~> 7.0')
    end
    
    it 'adds a gem with options' do
      config = described_class.new
      config.add_gem('rails', '~> 7.0', { require: false })
      
      expect(config.gems.length).to eq(1)
      expect(config.gems.first.options).to eq({ require: false })
    end
  end
  
  describe '#enable_authentication' do
    it 'adds authentication feature with default provider' do
      config = described_class.new
      config.enable_authentication
      
      expect(config.features[:authentication]).to be_a(Tenant::Configuration::AuthenticationConfiguration)
      expect(config.features[:authentication].provider).to eq(:rodauth)
    end
    
    it 'adds authentication feature with specified provider' do
      config = described_class.new
      config.enable_authentication(:devise)
      
      expect(config.features[:authentication].provider).to eq(:devise)
    end
    
    it 'configures passkeys when enabled' do
      config = described_class.new
      config.enable_authentication(:devise, { passkeys: true, passkey_options: { rp_name: 'Test App' } })
      
      expect(config.features[:authentication].passkeys).to be true
      expect(config.features[:authentication].passkey_options).to eq({ rp_name: 'Test App' })
    end
  end
  
  describe '#set_database' do
    it 'sets the database type and options' do
      config = described_class.new
      config.set_database(:postgresql, { username: 'postgres', password: 'password' })
      
      expect(config.database).to eq(:postgresql)
      expect(config.database_options).to eq({ username: 'postgres', password: 'password' })
    end
  end
  
  describe '#enable_search_engine' do
    it 'sets the search engine and options' do
      config = described_class.new
      config.enable_search_engine(:elasticsearch, { host: 'http://localhost:9200' })
      
      expect(config.search_engine).to eq(:elasticsearch)
      expect(config.search_engine_options).to eq({ host: 'http://localhost:9200' })
    end
  end
  
  describe '#enable_vector_db' do
    it 'sets the vector database and options' do
      config = described_class.new
      config.enable_vector_db(:pgvector, { dimensions: 1536 })
      
      expect(config.vector_db).to eq(:pgvector)
      expect(config.vector_db_options).to eq({ dimensions: 1536 })
    end
  end
  
  describe '#set_embedding_provider' do
    it 'sets the embedding provider and options' do
      config = described_class.new
      config.set_embedding_provider(:openai, { model: 'text-embedding-ada-002' })
      
      expect(config.embedding_provider).to eq(:openai)
      expect(config.embedding_provider_options).to eq({ model: 'text-embedding-ada-002' })
    end
  end
  
  describe '#to_h' do
    it 'returns a hash representation of the configuration' do
      config = described_class.new
      config.frontend = :react
      config.add_gem('rails', '~> 7.0')
      config.enable_authentication(:devise)
      config.set_database(:postgresql, { username: 'postgres' })
      config.enable_search_engine(:elasticsearch, { host: 'http://localhost:9200' })
      config.enable_vector_db(:pgvector, { dimensions: 1536 })
      config.set_embedding_provider(:openai, { model: 'text-embedding-ada-002' })
      
      hash = config.to_h
      
      expect(hash[:frontend]).to eq(:react)
      expect(hash[:gems].first[:name]).to eq('rails')
      expect(hash[:features][:authentication][:provider]).to eq(:devise)
      expect(hash[:database]).to eq(:postgresql)
      expect(hash[:database_options]).to eq({ username: 'postgres' })
      expect(hash[:search_engine]).to eq(:elasticsearch)
      expect(hash[:search_engine_options]).to eq({ host: 'http://localhost:9200' })
      expect(hash[:vector_db]).to eq(:pgvector)
      expect(hash[:vector_db_options]).to eq({ dimensions: 1536 })
      expect(hash[:embedding_provider]).to eq(:openai)
      expect(hash[:embedding_provider_options]).to eq({ model: 'text-embedding-ada-002' })
    end
  end
end 