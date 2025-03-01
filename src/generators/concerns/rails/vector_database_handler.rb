module Tenant
  module VectorDatabaseHandler
    def setup_vector_database
      return unless @configuration&.vector_db
      
      log_info("Setting up vector database: #{@configuration.vector_db}")
      
      FileUtils.chdir @rails_all_path do
        case @configuration.vector_db
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
      
      # Setup embedding provider if configured
      setup_embedding_provider if @configuration&.embedding_provider
    end
    
    private
    
    def setup_pgvector
      # Add pgvector gem if not already added
      unless @configuration.gems.any? { |g| g[:name] == 'pgvector' }
        @configuration.add_gem('pgvector', '~> 0.2.0')
      end
      
      # Create initializer
      FileUtils.mkdir_p "#{@rails_all_path}/config/initializers"
      
      File.open("#{@rails_all_path}/config/initializers/pgvector.rb", "w") do |f|
        f.puts "# PGVector configuration"
        f.puts "require 'pgvector/active_record'"
        f.puts ""
        f.puts "# Set vector dimensions"
        f.puts "Rails.application.config.vector_dimensions = #{@configuration.vector_db_options[:dimensions] || 1536}"
      end
      
      # Create migration for enabling pgvector extension
      FileUtils.mkdir_p "#{@rails_all_path}/db/migrate"
      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
      
      File.open("#{@rails_all_path}/db/migrate/#{timestamp}_enable_pgvector.rb", "w") do |f|
        f.puts "class EnablePgvector < ActiveRecord::Migration[7.0]"
        f.puts "  def up"
        f.puts "    execute 'CREATE EXTENSION IF NOT EXISTS vector'"
        f.puts "  end"
        f.puts ""
        f.puts "  def down"
        f.puts "    execute 'DROP EXTENSION IF EXISTS vector'"
        f.puts "  end"
        f.puts "end"
      end
      
      # Create VectorSearchable concern
      FileUtils.mkdir_p "#{@rails_all_path}/app/models/concerns"
      
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
        f.puts ""
        f.puts "    # RAG helper method to retrieve relevant documents for a query"
        f.puts "    def retrieve_for_rag(query, limit: 5, min_similarity: 0.7)"
        f.puts "      vector_search(query, limit: limit, min_similarity: min_similarity)"
        f.puts "    end"
        f.puts "  end"
        f.puts "end"
      end
      
      # Add environment variable instructions to README
      update_readme_with_env_vars("PGVECTOR_DIMENSIONS", "Dimensions for vector embeddings (default: 1536)")
      
      log_info("PGVector configured successfully")
    end
    
    def setup_qdrant
      # Add qdrant-ruby gem if not already added
      unless @configuration.gems.any? { |g| g[:name] == 'qdrant-ruby' }
        @configuration.add_gem('qdrant-ruby', '~> 0.9.0')
      end
      
      # Create initializer
      FileUtils.mkdir_p "#{@rails_all_path}/config/initializers"
      
      File.open("#{@rails_all_path}/config/initializers/qdrant.rb", "w") do |f|
        f.puts "# Qdrant configuration"
        f.puts "require 'qdrant'"
        f.puts ""
        f.puts "# Configure Qdrant client"
        f.puts "Rails.application.config.qdrant = Qdrant::Client.new("
        f.puts "  url: ENV['QDRANT_URL'] || 'http://localhost:6333',"
        f.puts "  api_key: ENV['QDRANT_API_KEY']"
        f.puts ")"
        f.puts ""
        f.puts "# Set vector dimensions"
        f.puts "Rails.application.config.vector_dimensions = #{@configuration.vector_db_options[:dimensions] || 1536}"
      end
      
      # Create VectorSearchable concern
      FileUtils.mkdir_p "#{@rails_all_path}/app/models/concerns"
      
      File.open("#{@rails_all_path}/app/models/concerns/vector_searchable.rb", "w") do |f|
        f.puts "module VectorSearchable"
        f.puts "  extend ActiveSupport::Concern"
        f.puts ""
        f.puts "  included do"
        f.puts "    # Add callbacks to update Qdrant when record changes"
        f.puts "    after_create :create_vector_in_qdrant"
        f.puts "    after_update :update_vector_in_qdrant, if: -> { embedding_source_changed? }"
        f.puts "    after_destroy :delete_vector_from_qdrant"
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
        f.puts "  def create_vector_in_qdrant"
        f.puts "    return unless self.class.embedding_provider"
        f.puts ""
        f.puts "    # Generate embedding using the configured provider"
        f.puts "    vector = self.class.embedding_provider.embed(embedding_source)"
        f.puts ""
        f.puts "    # Store in Qdrant"
        f.puts "    qdrant_client.upsert_points("
        f.puts "      collection_name: self.class.qdrant_collection_name,"
        f.puts "      points: [{"
        f.puts "        id: self.id,"
        f.puts "        vector: vector,"
        f.puts "        payload: self.as_json"
        f.puts "      }]"
        f.puts "    )"
        f.puts "  end"
        f.puts ""
        f.puts "  def update_vector_in_qdrant"
        f.puts "    create_vector_in_qdrant"
        f.puts "  end"
        f.puts ""
        f.puts "  def delete_vector_from_qdrant"
        f.puts "    qdrant_client.delete_points("
        f.puts "      collection_name: self.class.qdrant_collection_name,"
        f.puts "      points: [self.id]"
        f.puts "    )"
        f.puts "  end"
        f.puts ""
        f.puts "  def qdrant_client"
        f.puts "    Rails.application.config.qdrant"
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
        f.puts "    # Get the Qdrant collection name for this model"
        f.puts "    def qdrant_collection_name"
        f.puts "      @qdrant_collection_name ||= self.name.underscore.pluralize"
        f.puts "    end"
        f.puts ""
        f.puts "    # Ensure the Qdrant collection exists"
        f.puts "    def ensure_qdrant_collection"
        f.puts "      client = Rails.application.config.qdrant"
        f.puts "      begin"
        f.puts "        client.get_collection(collection_name: qdrant_collection_name)"
        f.puts "      rescue Qdrant::ApiError"
        f.puts "        # Collection doesn't exist, create it"
        f.puts "        client.create_collection("
        f.puts "          collection_name: qdrant_collection_name,"
        f.puts "          vectors_config: {"
        f.puts "            size: Rails.application.config.vector_dimensions,"
        f.puts "            distance: 'Cosine'"
        f.puts "          }"
        f.puts "        )"
        f.puts "      end"
        f.puts "    end"
        f.puts ""
        f.puts "    # Search by vector similarity"
        f.puts "    def vector_search(query, limit: 10, min_similarity: 0.7)"
        f.puts "      # Generate embedding for the query"
        f.puts "      query_embedding = embedding_provider.embed(query)"
        f.puts ""
        f.puts "      # Ensure collection exists"
        f.puts "      ensure_qdrant_collection"
        f.puts ""
        f.puts "      # Search in Qdrant"
        f.puts "      results = Rails.application.config.qdrant.search_points("
        f.puts "        collection_name: qdrant_collection_name,"
        f.puts "        vector: query_embedding,"
        f.puts "        limit: limit,"
        f.puts "        score_threshold: min_similarity"
        f.puts "      )"
        f.puts ""
        f.puts "      # Fetch records by ID"
        f.puts "      ids = results.map { |r| r[:id] }"
        f.puts "      where(id: ids).sort_by { |record| ids.index(record.id) }"
        f.puts "    end"
        f.puts ""
        f.puts "    # RAG helper method to retrieve relevant documents for a query"
        f.puts "    def retrieve_for_rag(query, limit: 5, min_similarity: 0.7)"
        f.puts "      vector_search(query, limit: limit, min_similarity: min_similarity)"
        f.puts "    end"
        f.puts "  end"
        f.puts "end"
      end
      
      # Add environment variable instructions to README
      update_readme_with_env_vars("QDRANT_URL", "URL for your Qdrant instance (default: http://localhost:6333)")
      update_readme_with_env_vars("QDRANT_API_KEY", "API key for your Qdrant instance")
      
      log_info("Qdrant configured successfully")
    end
    
    def setup_weaviate
      # Add weaviate-ruby gem if not already added
      unless @configuration.gems.any? { |g| g[:name] == 'weaviate-ruby' }
        @configuration.add_gem('weaviate-ruby', '~> 0.8.0')
      end
      
      # Implementation for Weaviate setup would go here
      log_info("Weaviate configuration not yet implemented")
    end
    
    def setup_pinecone
      # Add pinecone gem if not already added
      unless @configuration.gems.any? { |g| g[:name] == 'pinecone' }
        @configuration.add_gem('pinecone', '~> 0.1.6')
      end
      
      # Implementation for Pinecone setup would go here
      log_info("Pinecone configuration not yet implemented")
    end
    
    def setup_embedding_provider
      return unless @configuration&.embedding_provider
      
      log_info("Setting up embedding provider: #{@configuration.embedding_provider}")
      
      # Create initializer
      FileUtils.mkdir_p "#{@rails_all_path}/config/initializers"
      
      File.open("#{@rails_all_path}/config/initializers/embedding_provider.rb", "w") do |f|
        f.puts "# Embedding Provider configuration"
        f.puts "Rails.application.config.embedding_provider = :#{@configuration.embedding_provider}"
        f.puts "Rails.application.config.embedding_provider_options = #{@configuration.embedding_provider_options.inspect}"
      end
      
      # Create embedding provider service directory
      FileUtils.mkdir_p "#{@rails_all_path}/app/services"
      
      # Create embedding provider factory
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
      
      # Create specific embedding provider implementations
      case @configuration.embedding_provider
      when :openai
        setup_openai_embedding
      when :huggingface
        setup_huggingface_embedding
      when :cohere
        setup_cohere_embedding
      end
      
      log_info("Embedding provider configured successfully")
    end
    
    def setup_openai_embedding
      # Add openai gem if not already added
      unless @configuration.gems.any? { |g| g[:name] == 'ruby-openai' }
        @configuration.add_gem('ruby-openai', '~> 5.1')
      end
      
      # Create OpenAI embedding provider
      File.open("#{@rails_all_path}/app/services/open_ai_embedding.rb", "w") do |f|
        f.puts "class OpenAIEmbedding"
        f.puts "  def initialize"
        f.puts "    @model = Rails.application.config.embedding_provider_options[:model] || 'text-embedding-ada-002'"
        f.puts "    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])"
        f.puts "  end"
        f.puts ""
        f.puts "  def embed(text)"
        f.puts "    return [] if text.blank?"
        f.puts ""
        f.puts "    # Truncate text if it's too long (OpenAI has token limits)"
        f.puts "    truncated_text = text.to_s.truncate(8000)"
        f.puts ""
        f.puts "    # Call OpenAI API to get embeddings"
        f.puts "    response = @client.embeddings("
        f.puts "      parameters: {"
        f.puts "        model: @model,"
        f.puts "        input: truncated_text"
        f.puts "      }"
        f.puts "    )"
        f.puts ""
        f.puts "    # Extract the embedding vector"
        f.puts "    response.dig('data', 0, 'embedding')"
        f.puts "  rescue => e"
        f.puts "    Rails.logger.error \"Error generating OpenAI embedding: #{e.message}\""
        f.puts "    []"
        f.puts "  end"
        f.puts "end"
      end
      
      # Add environment variable instructions to README
      update_readme_with_env_vars("OPENAI_API_KEY", "API key for OpenAI")
    end
    
    def setup_huggingface_embedding
      # Add http gem if not already added
      unless @configuration.gems.any? { |g| g[:name] == 'http' }
        @configuration.add_gem('http', '~> 5.1')
      end
      
      # Create HuggingFace embedding provider
      File.open("#{@rails_all_path}/app/services/hugging_face_embedding.rb", "w") do |f|
        f.puts "class HuggingFaceEmbedding"
        f.puts "  def initialize"
        f.puts "    @model = Rails.application.config.embedding_provider_options[:model] || 'sentence-transformers/all-mpnet-base-v2'"
        f.puts "    @api_url = \"https://api-inference.huggingface.co/pipeline/feature-extraction/#{@model}\""
        f.puts "  end"
        f.puts ""
        f.puts "  def embed(text)"
        f.puts "    return [] if text.blank?"
        f.puts ""
        f.puts "    # Truncate text if it's too long"
        f.puts "    truncated_text = text.to_s.truncate(2000)"
        f.puts ""
        f.puts "    # Call HuggingFace API to get embeddings"
        f.puts "    response = HTTP.auth(\"Bearer #{ENV['HUGGINGFACE_API_KEY']}\")"
        f.puts "                   .post(@api_url, json: { inputs: truncated_text, options: { wait_for_model: true } })"
        f.puts ""
        f.puts "    if response.status.success?"
        f.puts "      JSON.parse(response.body.to_s)"
        f.puts "    else"
        f.puts "      Rails.logger.error \"Error from HuggingFace API: #{response.body}\""
        f.puts "      []"
        f.puts "    end"
        f.puts "  rescue => e"
        f.puts "    Rails.logger.error \"Error generating HuggingFace embedding: #{e.message}\""
        f.puts "    []"
        f.puts "  end"
        f.puts "end"
      end
      
      # Add environment variable instructions to README
      update_readme_with_env_vars("HUGGINGFACE_API_KEY", "API key for HuggingFace")
    end
    
    def setup_cohere_embedding
      # Add cohere gem if not already added
      unless @configuration.gems.any? { |g| g[:name] == 'cohere-ruby' }
        @configuration.add_gem('cohere-ruby', '~> 0.9.0')
      end
      
      # Create Cohere embedding provider
      File.open("#{@rails_all_path}/app/services/cohere_embedding.rb", "w") do |f|
        f.puts "class CohereEmbedding"
        f.puts "  def initialize"
        f.puts "    @model = Rails.application.config.embedding_provider_options[:model] || 'embed-english-v3.0'"
        f.puts "    @client = Cohere::Client.new(api_key: ENV['COHERE_API_KEY'])"
        f.puts "  end"
        f.puts ""
        f.puts "  def embed(text)"
        f.puts "    return [] if text.blank?"
        f.puts ""
        f.puts "    # Truncate text if it's too long"
        f.puts "    truncated_text = text.to_s.truncate(2048)"
        f.puts ""
        f.puts "    # Call Cohere API to get embeddings"
        f.puts "    response = @client.embed("
        f.puts "      texts: [truncated_text],"
        f.puts "      model: @model,"
        f.puts "      input_type: 'search_document'"
        f.puts "    )"
        f.puts ""
        f.puts "    response.embeddings.first"
        f.puts "  rescue => e"
        f.puts "    Rails.logger.error \"Error generating Cohere embedding: #{e.message}\""
        f.puts "    []"
        f.puts "  end"
        f.puts "end"
      end
      
      # Add environment variable instructions to README
      update_readme_with_env_vars("COHERE_API_KEY", "API key for Cohere")
    end
  end
end 