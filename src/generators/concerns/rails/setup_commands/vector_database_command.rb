require_relative 'base_command'

module Tenant
  module Rails
    class VectorDatabaseCommand < BaseCommand
      def execute
        return unless @configuration&.vector_db
        
        log_info("Setting up vector database: #{@configuration.vector_db}")
        
        FileUtils.chdir @rails_path do
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
        setup_embedding_provider if @configuration.embedding_provider
      end
      
      private
      
      def setup_pgvector
        # Add pgvector gem if not already added
        unless @configuration.gems.any? { |g| g[:name] == 'pgvector' }
          @configuration.add_gem('pgvector', '~> 0.2.0')
        end
        
        # Create initializer
        FileUtils.mkdir_p "#{@rails_path}/config/initializers"
        
        File.open("#{@rails_path}/config/initializers/pgvector.rb", "w") do |f|
          f.puts "# PGVector configuration"
          f.puts "require 'pgvector/active_record'"
          f.puts ""
          f.puts "# Set vector dimensions"
          f.puts "Rails.application.config.vector_dimensions = #{@configuration.vector_db_options[:dimensions] || 1536}"
        end
        
        # Create concern
        FileUtils.mkdir_p "#{@rails_path}/app/models/concerns"
        
        File.open("#{@rails_path}/app/models/concerns/vector_searchable.rb", "w") do |f|
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
          f.puts "  # Search for similar records"
          f.puts "  def find_similar(limit: 10, min_similarity: 0.7)"
          f.puts "    return [] unless embedding.present?"
          f.puts "    "
          f.puts "    self.class.where.not(id: id)"
          f.puts "      .where('cosine_similarity(embedding, ?) > ?', embedding, min_similarity)"
          f.puts "      .order(Arel.sql(\"cosine_similarity(embedding, '\#{embedding}') DESC\"))"
          f.puts "      .limit(limit)"
          f.puts "  end"
          f.puts ""
          f.puts "  # Retrieve context for RAG applications"
          f.puts "  def retrieve_for_rag"
          f.puts "    # Return a formatted string with the record's content"
          f.puts "    self.class.embedding_fields.map do |field|"
          f.puts "      value = self.send(field)"
          f.puts "      \"#{field.to_s.humanize}: #{value}\" if value.present?"
          f.puts "    end.compact.join(\"\\n\")"
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
          f.puts "        .order(Arel.sql(\"cosine_similarity(embedding, '\#{query_embedding}') DESC\"))"
          f.puts "        .limit(limit)"
          f.puts "    end"
          f.puts "  end"
          f.puts "end"
        end
        
        # Add migration to enable pgvector extension
        timestamp = Time.now.strftime("%Y%m%d%H%M%S")
        migration_path = "#{@rails_path}/db/migrate/#{timestamp}_enable_pgvector.rb"
        
        File.open(migration_path, "w") do |f|
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
        
        # Update README with environment variables
        update_readme_with_env_vars("OPENAI_API_KEY", "API key for OpenAI (required for vector embeddings)")
      end
      
      def setup_embedding_provider
        return unless @configuration&.embedding_provider
        
        log_info("Setting up embedding provider: #{@configuration.embedding_provider}")
        
        # Create initializer
        FileUtils.mkdir_p "#{@rails_path}/config/initializers"
        
        File.open("#{@rails_path}/config/initializers/embedding_provider.rb", "w") do |f|
          f.puts "# Embedding Provider configuration"
          f.puts "Rails.application.config.embedding_provider = :#{@configuration.embedding_provider}"
          f.puts "Rails.application.config.embedding_provider_options = #{@configuration.embedding_provider_options.inspect}"
        end
        
        # Create embedding provider class
        FileUtils.mkdir_p "#{@rails_path}/app/services"
        
        File.open("#{@rails_path}/app/services/embedding_provider.rb", "w") do |f|
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
        
        # Setup specific provider
        case @configuration.embedding_provider
        when :openai
          setup_openai_embedding
        when :huggingface
          setup_huggingface_embedding
        when :cohere
          setup_cohere_embedding
        end
      end
      
      def setup_openai_embedding
        # Add openai gem if not already added
        unless @configuration.gems.any? { |g| g[:name] == 'ruby-openai' }
          @configuration.add_gem('ruby-openai', '~> 5.0')
        end
        
        # Create OpenAI embedding provider
        File.open("#{@rails_path}/app/services/open_ai_embedding.rb", "w") do |f|
          f.puts "class OpenAIEmbedding"
          f.puts "  def initialize"
          f.puts "    @model = Rails.application.config.embedding_provider_options[:model] || 'text-embedding-ada-002'"
          f.puts "    @api_key = ENV['OPENAI_API_KEY']"
          f.puts "    @client = OpenAI::Client.new(access_token: @api_key)"
          f.puts "  end"
          f.puts ""
          f.puts "  def embed(text)"
          f.puts "    return [] if text.blank?"
          f.puts ""
          f.puts "    # Truncate text if it's too long (OpenAI has token limits)"
          f.puts "    truncated_text = text.to_s.truncate(8000)"
          f.puts ""
          f.puts "    begin"
          f.puts "      response = @client.embeddings("
          f.puts "        parameters: {"
          f.puts "          model: @model,"
          f.puts "          input: truncated_text"
          f.puts "        }"
          f.puts "      )"
          f.puts ""
          f.puts "      # Extract the embedding vector from the response"
          f.puts "      response.dig('data', 0, 'embedding')"
          f.puts "    rescue => e"
          f.puts "      Rails.logger.error \"Error generating embedding: #{e.message}\""
          f.puts "      []"
          f.puts "    end"
          f.puts "  end"
          f.puts "end"
        end
        
        # Update README with environment variables
        update_readme_with_env_vars("OPENAI_API_KEY", "API key for OpenAI (required for vector embeddings)")
      end
      
      def update_readme_with_env_vars(var_name, description)
        readme_path = "#{@rails_path}/README.md"
        return unless File.exist?(readme_path)
        
        readme_content = File.read(readme_path)
        
        unless readme_content.include?(var_name)
          env_vars_section = readme_content.match(/## Environment Variables\s*\n(.*?)(\n##|\z)/m)
          
          if env_vars_section
            updated_section = env_vars_section[1] + "- `#{var_name}`: #{description}\n"
            updated_readme = readme_content.sub(env_vars_section[1], updated_section)
            File.write(readme_path, updated_readme)
          else
            # Add a new Environment Variables section
            new_section = "\n## Environment Variables\n\n- `#{var_name}`: #{description}\n"
            File.write(readme_path, readme_content + new_section)
          end
        end
      end
    end
  end
end 