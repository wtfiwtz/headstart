module Tenant
  module ModelGenerator
    def generate_models
      log_info("Generating models for #{@models.length} models")
      
      @models.each do |model|
        generate_model(model)
      end
    end
    
    private
    
    def generate_model(model)
      log_info("Generating model for #{model.name}")
      
      # Create the model file
      model_path = "#{@rails_all_path}/app/models/#{model.name.underscore}.rb"
      
      # Create the model content
      model_content = <<~RUBY
        class #{model.name} < ApplicationRecord
          #{generate_integrations(model)}
          #{generate_associations(model)}
          #{generate_validations(model)}
          #{generate_scopes(model)}
          #{generate_callbacks(model)}
        end
      RUBY
      
      # Write the model file
      File.write(model_path, model_content)
      
      # Generate migration for vector column if needed
      generate_vector_migration(model) if @configuration&.vector_db == :pgvector
    end
    
    def generate_integrations(model)
      integrations = []
      
      # Add search engine integration if configured
      if @configuration&.search_engine
        integrations << generate_search_engine_integration(model)
      end
      
      # Add vector database integration if configured
      if @configuration&.vector_db
        integrations << generate_vector_db_integration(model)
      end
      
      integrations.compact.join("\n  ")
    end
    
    def generate_associations(model)
      return "" unless model.associations&.any?
      
      associations = model.associations.map do |assoc|
        case assoc.kind
        when "has_many"
          "has_many :#{assoc.name}#{generate_association_options(assoc.attrs)}"
        when "has_one"
          "has_one :#{assoc.name}#{generate_association_options(assoc.attrs)}"
        when "belongs_to"
          "belongs_to :#{assoc.name}#{generate_association_options(assoc.attrs)}"
        when "has_and_belongs_to_many"
          "has_and_belongs_to_many :#{assoc.name}#{generate_association_options(assoc.attrs)}"
        end
      end
      
      associations.join("\n  ")
    end
    
    def generate_association_options(attrs)
      return "" unless attrs&.any?
      
      options = attrs.map do |key, value|
        if value.is_a?(Symbol) || (value.is_a?(String) && value.start_with?(":"))
          "#{key}: #{value}"
        else
          "#{key}: #{value.inspect}"
        end
      end
      
      ", #{options.join(", ")}"
    end
    
    def generate_validations(model)
      # Add basic validations based on attribute names and types
      validations = []
      
      model.attributes.each do |attr|
        # Presence validations for common required fields
        if ['name', 'title', 'email', 'username'].include?(attr.name)
          validations << "validates :#{attr.name}, presence: true"
        end
        
        # Format validations for specific field types
        if attr.name == 'email'
          validations << "validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: -> { email.present? }"
        end
        
        # Length validations for string fields
        if attr.type == 'string'
          validations << "validates :#{attr.name}, length: { maximum: 255 }, if: -> { #{attr.name}.present? }"
        end
        
        # Numericality validations for numeric fields
        if ['integer', 'float', 'decimal'].include?(attr.type.to_s)
          validations << "validates :#{attr.name}, numericality: true, if: -> { #{attr.name}.present? }"
        end
      end
      
      validations.join("\n  ")
    end
    
    def generate_scopes(model)
      scopes = []
      
      # Add common scopes
      scopes << "scope :recent, -> { order(created_at: :desc) }"
      
      # Add scopes based on boolean attributes
      model.attributes.each do |attr|
        if attr.type.to_s == 'boolean'
          scopes << "scope :#{attr.name}, -> { where(#{attr.name}: true) }"
          scopes << "scope :not_#{attr.name}, -> { where(#{attr.name}: false) }"
        end
      end
      
      # Add scopes for datetime fields
      datetime_attrs = model.attributes.select { |attr| ['datetime', 'date'].include?(attr.type.to_s) }
      if datetime_attrs.any?
        scopes << "scope :created_after, ->(date) { where('created_at >= ?', date) }"
        scopes << "scope :created_before, ->(date) { where('created_at <= ?', date) }"
      end
      
      scopes.join("\n  ")
    end
    
    def generate_callbacks(model)
      callbacks = []
      
      # Add slug generation for models with name or title
      if model.attributes.any? { |attr| ['name', 'title'].include?(attr.name) }
        callbacks << "before_save :generate_slug, if: -> { slug.blank? && (name_changed? || title_changed?) }"
        callbacks << ""
        callbacks << "private"
        callbacks << ""
        callbacks << "def generate_slug"
        callbacks << "  self.slug = #{model.attributes.any? { |attr| attr.name == 'name' } ? 'name' : 'title'}.parameterize"
        callbacks << "end"
      end
      
      callbacks.join("\n  ")
    end
    
    def generate_search_engine_integration(model)
      case @configuration.search_engine
      when :elasticsearch
        generate_elasticsearch_integration(model)
      when :meilisearch
        generate_meilisearch_integration(model)
      else
        ""
      end
    end
    
    def generate_elasticsearch_integration(model)
      # Determine which fields are searchable (string and text fields)
      searchable_fields = model.attributes
        .select { |attr| ['string', 'text'].include?(attr.type.to_s) }
        .map { |attr| attr.name }
      
      # Determine which associations to include in search
      searchable_associations = {}
      model.associations.each do |assoc|
        if ['belongs_to', 'has_one'].include?(assoc.kind)
          searchable_associations[assoc.name] = { only: [:id, :name, :title].select { |f| model_has_field?(assoc.name, f) } }
        end
      end
      
      <<~RUBY
        include Searchable
        
        # Define which fields are searchable
        def self.searchable_fields
          #{searchable_fields.map { |f| ":#{f}" }.join(', ')}
        end
        
        # Define which associations to include in search
        def self.searchable_associations
          {
            #{searchable_associations.map { |assoc, options| "#{assoc}: { only: #{options[:only].inspect} }" }.join(",\n    ")}
          }
        end
      RUBY
    end
    
    def generate_meilisearch_integration(model)
      # Determine which fields are searchable by word start (names, titles, etc.)
      word_start_fields = model.attributes
        .select { |attr| ['name', 'title', 'username', 'email'].include?(attr.name) }
        .map { |attr| attr.name }
      
      # Determine which fields are searchable by word middle (all string fields)
      word_middle_fields = model.attributes
        .select { |attr| attr.type.to_s == 'string' && !word_start_fields.include?(attr.name) }
        .map { |attr| attr.name }
      
      # Determine which fields are searchable by text start (headings, summaries)
      text_start_fields = model.attributes
        .select { |attr| attr.type.to_s == 'text' && ['summary', 'headline', 'subtitle'].include?(attr.name) }
        .map { |attr| attr.name }
      
      # Determine which fields are searchable by text middle (all text fields)
      text_middle_fields = model.attributes
        .select { |attr| attr.type.to_s == 'text' && !text_start_fields.include?(attr.name) }
        .map { |attr| attr.name }
      
      # Determine which fields to highlight in search results
      highlight_fields = word_start_fields + text_start_fields
      
      <<~RUBY
        include Searchable
        
        # Define which fields to search by prefix
        def self.searchkick_word_start_fields
          #{word_start_fields.map { |f| ":#{f}" }.join(', ')}
        end
        
        # Define which fields to search by infix
        def self.searchkick_word_middle_fields
          #{word_middle_fields.map { |f| ":#{f}" }.join(', ')}
        end
        
        # Define which text fields to search by prefix
        def self.searchkick_text_start_fields
          #{text_start_fields.map { |f| ":#{f}" }.join(', ')}
        end
        
        # Define which text fields to search by infix
        def self.searchkick_text_middle_fields
          #{text_middle_fields.map { |f| ":#{f}" }.join(', ')}
        end
        
        # Define which fields to highlight in search results
        def self.searchkick_highlight_fields
          #{highlight_fields.map { |f| ":#{f}" }.join(', ')}
        end
        
        # Define what data to index
        def search_data
          {
            #{(model.attributes.map { |attr| "#{attr.name}: #{attr.name}" } + 
               model.associations.select { |assoc| ['belongs_to', 'has_one'].include?(assoc.kind) }
                     .map { |assoc| "#{assoc.name}_name: #{assoc.name}&.name" }).join(",\n    ")}
          }
        end
      RUBY
    end
    
    def generate_vector_db_integration(model)
      case @configuration.vector_db
      when :pgvector
        generate_pgvector_integration(model)
      when :qdrant
        generate_qdrant_integration(model)
      when :weaviate, :pinecone
        generate_external_vector_db_integration(model)
      else
        ""
      end
    end
    
    def generate_pgvector_integration(model)
      # Determine which fields to use for embedding (text and string fields)
      embedding_fields = model.attributes
        .select { |attr| ['string', 'text'].include?(attr.type.to_s) }
        .map { |attr| attr.name }
      
      # Prioritize important fields
      important_fields = ['name', 'title', 'description', 'content', 'body', 'summary']
      prioritized_fields = important_fields.select { |f| embedding_fields.include?(f) }
      
      # Add remaining fields
      remaining_fields = embedding_fields - prioritized_fields
      embedding_fields = prioritized_fields + remaining_fields
      
      <<~RUBY
        include VectorSearchable
        
        # Define which fields to use for embedding
        def self.embedding_fields
          #{embedding_fields.map { |f| ":#{f}" }.join(', ')}
        end
      RUBY
    end
    
    def generate_qdrant_integration(model)
      # Determine which fields to use for embedding (text and string fields)
      embedding_fields = model.attributes
        .select { |attr| ['string', 'text'].include?(attr.type.to_s) }
        .map { |attr| attr.name }
      
      # Prioritize important fields
      important_fields = ['name', 'title', 'description', 'content', 'body', 'summary']
      prioritized_fields = important_fields.select { |f| embedding_fields.include?(f) }
      
      # Add remaining fields
      remaining_fields = embedding_fields - prioritized_fields
      embedding_fields = prioritized_fields + remaining_fields
      
      <<~RUBY
        include VectorSearchable
        
        # Define which fields to use for embedding
        def self.embedding_fields
          #{embedding_fields.map { |f| ":#{f}" }.join(', ')}
        end
        
        # Ensure Qdrant collection exists
        self.ensure_qdrant_collection
      RUBY
    end
    
    def generate_external_vector_db_integration(model)
      # Determine which fields to use for embedding (text and string fields)
      embedding_fields = model.attributes
        .select { |attr| ['string', 'text'].include?(attr.type.to_s) }
        .map { |attr| attr.name }
      
      # Prioritize important fields
      important_fields = ['name', 'title', 'description', 'content', 'body', 'summary']
      prioritized_fields = important_fields.select { |f| embedding_fields.include?(f) }
      
      # Add remaining fields
      remaining_fields = embedding_fields - prioritized_fields
      embedding_fields = prioritized_fields + remaining_fields
      
      <<~RUBY
        include VectorSearchable
        
        # Define which fields to use for embedding
        def self.embedding_fields
          #{embedding_fields.map { |f| ":#{f}" }.join(', ')}
        end
      RUBY
    end
    
    def generate_vector_migration(model)
      # Create migration for adding vector column
      FileUtils.mkdir_p "#{@rails_all_path}/db/migrate"
      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
      
      File.open("#{@rails_all_path}/db/migrate/#{timestamp}_add_embedding_to_#{model.name.underscore.pluralize}.rb", "w") do |f|
        f.puts "class AddEmbeddingTo#{model.name.pluralize} < ActiveRecord::Migration[7.0]"
        f.puts "  def change"
        f.puts "    # Add vector column for embeddings"
        f.puts "    add_column :#{model.name.underscore.pluralize}, :embedding, :vector, dimensions: Rails.application.config.vector_dimensions"
        f.puts ""
        f.puts "    # Add index for similarity search"
        f.puts "    execute <<-SQL"
        f.puts "      CREATE INDEX #{model.name.underscore.pluralize}_embedding_idx ON #{model.name.underscore.pluralize} USING ivfflat (embedding vector_cosine_ops)"
        f.puts "    SQL"
        f.puts "  end"
        f.puts "end"
      end
    end
    
    def model_has_field?(model_name, field_name)
      # Check if a related model has a specific field
      # This is a simplification - in a real implementation, you would check the actual model
      ['id', 'name', 'title'].include?(field_name)
    end
  end
end 