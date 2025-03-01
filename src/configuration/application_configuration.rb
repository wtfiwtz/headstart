require_relative 'gem_configuration'
require_relative 'feature_configuration'

module Tenant
  module Configuration
    class ApplicationConfiguration
      attr_accessor :frontend, :gems, :css_framework, :controller_inheritance, :form_builder, :monitoring
      attr_accessor :database, :database_options, :search_engine, :search_engine_options
      attr_accessor :vector_db, :vector_db_options, :embedding_provider, :embedding_provider_options
      attr_reader :features
      
      def initialize
        @frontend = :mvc # Default to traditional MVC
        @gems = [] # List of gems to include
        @features = {} # Features to enable (e.g., authentication, file_upload)
        @css_framework = :bootstrap # Default CSS framework
        @controller_inheritance = true
        @form_builder = :default # Default Rails form builder (:simple_form, :formtastic)
        @monitoring = [] # List of monitoring tools to include (:new_relic, :datadog, :sentry)
        @database = :sqlite # Default database (:sqlite, :postgresql, :mysql)
        @database_options = {} # Database configuration options
        @search_engine = nil # Search engine (:elasticsearch, :meilisearch, nil)
        @search_engine_options = {} # Search engine configuration options
        @vector_db = nil # Vector database (:pgvector, :qdrant, :weaviate, :pinecone, nil)
        @vector_db_options = {} # Vector database configuration options
        @embedding_provider = nil # Embedding provider (:openai, :huggingface, :cohere, nil)
        @embedding_provider_options = {} # Embedding provider configuration options
      end
      
      def add_gem(name, version = nil, options = {})
        @gems << GemConfiguration.new(name, version, options)
      end
      
      def enable_authentication(provider = :rodauth, options = {})
        passkeys = options.delete(:passkeys) || false
        passkey_options = options.delete(:passkey_options) || {}
        
        auth_config = AuthenticationConfiguration.new(provider, options)
        auth_config.passkeys = passkeys
        auth_config.passkey_options = passkey_options
        
        @features[:authentication] = auth_config
      end
      
      def enable_file_upload(provider = :active_storage, options = {})
        @features[:file_upload] = FileUploadConfiguration.new(provider, options)
      end
      
      def enable_background_jobs(provider = :sidekiq, options = {})
        @features[:background_jobs] = BackgroundJobsConfiguration.new(provider, options)
      end
      
      def add_monitoring_tool(tool)
        @monitoring << tool unless @monitoring.include?(tool)
      end
      
      def set_database(db_type, options = {})
        @database = db_type.to_sym
        @database_options = options
      end
      
      def enable_search_engine(engine, options = {})
        @search_engine = engine.to_sym
        @search_engine_options = options
      end
      
      def enable_vector_db(db_type, options = {})
        @vector_db = db_type.to_sym
        @vector_db_options = options
      end
      
      def set_embedding_provider(provider, options = {})
        @embedding_provider = provider.to_sym
        @embedding_provider_options = options
      end
      
      def to_h
        {
          frontend: @frontend,
          gems: @gems.map(&:to_h),
          features: @features.transform_values(&:to_h),
          css_framework: @css_framework,
          controller_inheritance: @controller_inheritance,
          form_builder: @form_builder,
          monitoring: @monitoring,
          database: @database,
          database_options: @database_options,
          search_engine: @search_engine,
          search_engine_options: @search_engine_options,
          vector_db: @vector_db,
          vector_db_options: @vector_db_options,
          embedding_provider: @embedding_provider,
          embedding_provider_options: @embedding_provider_options
        }
      end
    end
  end
end 