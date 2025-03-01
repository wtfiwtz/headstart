require 'spec_helper'
require 'test_helper'

RSpec.describe "Vector Database Integration" do
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
      
      # Mock method for setting up vector database
      def setup_vector_database
        case @configuration&.vector_db
        when :pgvector
          setup_pgvector
        when :qdrant
          setup_qdrant
        when :weaviate
          setup_weaviate
        when :pinecone
          setup_pinecone
        end
      end
      
      def setup_pgvector
        # Create initializer
        FileUtils.mkdir_p("#{@rails_all_path}/config/initializers")
        
        File.open("#{@rails_all_path}/config/initializers/pgvector.rb", "w") do |f|
          f.puts "# PGVector configuration"
          f.puts "require 'pgvector/active_record'"
          f.puts ""
          f.puts "# Set vector dimensions"
          f.puts "Rails.application.config.vector_dimensions = #{@configuration.vector_db_options[:dimensions] || 1536}"
        end
        
        # Create concern
        FileUtils.mkdir_p("#{@rails_all_path}/app/models/concerns")
        
        File.open("#{@rails_all_path}/app/models/concerns/vector_searchable.rb", "w") do |f|
          f.puts "module VectorSearchable"
          f.puts "  extend ActiveSupport::Concern"
          f.puts ""
          f.puts "  included do"
          f.puts "    # Add vector column to the model"
          f.puts "    has_vector :embedding, dimensions: Rails.application.config.vector_dimensions"
          f.puts ""
          f.puts "    # Callbacks to update embedding when record changes"
          f.puts "    after_save :update_embedding, if: -> { embedding_source_changed? }"
          f.puts "  end"
          f.puts ""
          f.puts "  # Define which fields to use for embedding"
          f.puts "  def embedding_source"
          f.puts "    self.class.embedding_fields.map { |field| self.send(field) }.join(' ')"
          f.puts "  end"
          f.puts ""
          f.puts "  def embedding_source_changed?"
          f.puts "    self.class.embedding_fields.any? { |field| saved_change_to_attribute?(field) }"
          f.puts "  end"
          f.puts ""
          f.puts "  def update_embedding"
          f.puts "    return unless self.class.embedding_provider"
          f.puts ""
          f.puts "    # Generate embedding using the configured provider"
          f.puts "    vector = self.class.embedding_provider.embed(embedding_source)"
          f.puts "    update_column(:embedding, vector)"
          f.puts "  end"
          f.puts ""
          f.puts "  class_methods do"
          f.puts "    # Define which fields to use for embedding (override in each model)"
          f.puts "    def embedding_fields"
          f.puts "      []"
          f.puts "    end"
          f.puts ""
          f.puts "    # Set the embedding provider"
          f.puts "    def embedding_provider"
          f.puts "      @embedding_provider ||= EmbeddingProvider.for(Rails.application.config.embedding_provider)"
          f.puts "    end"
          f.puts ""
          f.puts "    # Search by vector similarity"
          f.puts "    def vector_search(query, limit: 10, min_similarity: 0.7)"
          f.puts "      # Generate embedding for the query"
          f.puts "      query_embedding = embedding_provider.embed(query)"
          f.puts ""
          f.puts "      # Search by cosine similarity"
          f.puts "      where('cosine_similarity(embedding, ?) > ?', query_embedding, min_similarity)"
          f.puts "        .order(Arel.sql(\"cosine_similarity(embedding, '#{query_embedding}') DESC\"))"
          f.puts "        .limit(limit)"
          f.puts "    end"
          f.puts "  end"
          f.puts "end"
        end
      end
      
      def setup_qdrant
        # Implementation for Qdrant setup would go here
      end
      
      def setup_weaviate
        # Implementation for Weaviate setup would go here
      end
      
      def setup_pinecone
        # Implementation for Pinecone setup would go here
      end
      
      # Mock method for setting up embedding provider
      def setup_embedding_provider
        # Create initializer
        FileUtils.mkdir_p("#{@rails_all_path}/config/initializers")
        
        File.open("#{@rails_all_path}/config/initializers/embedding_provider.rb", "w") do |f|
          f.puts "# Embedding Provider configuration"
          f.puts "Rails.application.config.embedding_provider = :#{@configuration.embedding_provider}"
          f.puts "Rails.application.config.embedding_provider_options = #{@configuration.embedding_provider_options.inspect}"
        end
        
        # Create embedding provider class
        FileUtils.mkdir_p("#{@rails_all_path}/app/services")
        
        File.open("#{@rails_all_path}/app/services/embedding_provider.rb", "w") do |f|
          f.puts "class EmbeddingProvider"
          f.puts "  def self.for(provider)"
          f.puts "    case provider"
          f.puts "    when :openai"
          f.puts "      OpenAIEmbedding.new"
          f.puts "    when :huggingface"
          f.puts "      HuggingFaceEmbedding.new"
          f.puts "    when :cohere"
          f.puts "      CohereEmbedding.new"
          f.puts "    else"
          f.puts "      raise \"Unknown embedding provider: #{provider}\""
          f.puts "    end"
          f.puts "  end"
          f.puts "end"
        end
        
        # Create OpenAI embedding provider
        File.open("#{@rails_all_path}/app/services/open_ai_embedding.rb", "w") do |f|
          f.puts "class OpenAIEmbedding"
          f.puts "  def initialize"
          f.puts "    @model = Rails.application.config.embedding_provider_options[:model] || 'text-embedding-ada-002'"
          f.puts "    @api_key = ENV['OPENAI_API_KEY']"
          f.puts "  end"
          f.puts ""
          f.puts "  def embed(text)"
          f.puts "    # In a real implementation, this would call the OpenAI API"
          f.puts "    # For testing, we'll just return a random vector"
          f.puts "    Array.new(Rails.application.config.vector_dimensions) { rand(-1.0..1.0) }"
          f.puts "  end"
          f.puts "end"
        end
      end
    end
  end
  
  let(:configuration) do
    config = build(:application_configuration, :with_pgvector, :with_openai_embeddings)
    config
  end
  
  let(:handler) { test_class.new(configuration) }
  
  after do
    handler.cleanup
  end
  
  describe 'PGVector integration' do
    it 'creates PGVector initializer' do
      handler.setup_vector_database
      
      # Verify the PGVector initializer was created
      initializer_path = "#{handler.rails_all_path}/config/initializers/pgvector.rb"
      expect(File.exist?(initializer_path)).to be true
      
      # Verify the content of the initializer
      initializer_content = File.read(initializer_path)
      expect(initializer_content).to include('require \'pgvector/active_record\'')
      expect(initializer_content).to include('Rails.application.config.vector_dimensions')
    end
    
    it 'creates VectorSearchable concern' do
      handler.setup_vector_database
      
      # Verify the VectorSearchable concern was created
      concern_path = "#{handler.rails_all_path}/app/models/concerns/vector_searchable.rb"
      expect(File.exist?(concern_path)).to be true
      
      # Verify the content of the concern
      concern_content = File.read(concern_path)
      expect(concern_content).to include('module VectorSearchable')
      expect(concern_content).to include('has_vector :embedding')
      expect(concern_content).to include('def vector_search')
    end
  end
  
  describe 'Embedding provider integration' do
    it 'creates embedding provider initializer' do
      handler.setup_embedding_provider
      
      # Verify the embedding provider initializer was created
      initializer_path = "#{handler.rails_all_path}/config/initializers/embedding_provider.rb"
      expect(File.exist?(initializer_path)).to be true
      
      # Verify the content of the initializer
      initializer_content = File.read(initializer_path)
      expect(initializer_content).to include('Rails.application.config.embedding_provider = :openai')
    end
    
    it 'creates embedding provider service' do
      handler.setup_embedding_provider
      
      # Verify the embedding provider service was created
      service_path = "#{handler.rails_all_path}/app/services/embedding_provider.rb"
      expect(File.exist?(service_path)).to be true
      
      # Verify the content of the service
      service_content = File.read(service_path)
      expect(service_content).to include('class EmbeddingProvider')
      expect(service_content).to include('def self.for')
    end
    
    it 'creates OpenAI embedding provider' do
      handler.setup_embedding_provider
      
      # Verify the OpenAI embedding provider was created
      provider_path = "#{handler.rails_all_path}/app/services/open_ai_embedding.rb"
      expect(File.exist?(provider_path)).to be true
      
      # Verify the content of the provider
      provider_content = File.read(provider_path)
      expect(provider_content).to include('class OpenAIEmbedding')
      expect(provider_content).to include('def embed')
    end
  end
end 