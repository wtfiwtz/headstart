module Tenant
  module PythonConfigurationHandler
    def initialize_configuration(config)
      @config = config
      @python_path = config[:python_path] || "python-app"
      @framework_type = config[:framework_type] || "fastapi"
      @database_type = config[:database_type] || "sqlalchemy"
      @models = config[:models] || []
      @api_features = config[:api_features] || { pagination: true, sorting: true, filtering: true }
      @batch_jobs = config[:batch_jobs] || []
    end
    
    def validate_configuration
      # Ensure python_path is set
      unless @python_path
        raise ArgumentError, "Python path must be specified in configuration"
      end
      
      # Ensure framework_type is valid
      valid_framework_types = ["fastapi", "flask", "django"]
      unless valid_framework_types.include?(@framework_type.to_s.downcase)
        raise ArgumentError, "Invalid framework type: #{@framework_type}. Valid types are: #{valid_framework_types.join(', ')}"
      end
      
      # Ensure database_type is valid
      valid_db_types = ["sqlalchemy", "django-orm", "pony", "peewee", "mongodb"]
      unless valid_db_types.include?(@database_type.to_s.downcase)
        raise ArgumentError, "Invalid database type: #{@database_type}. Valid types are: #{valid_db_types.join(', ')}"
      end
      
      # Ensure models is an array
      unless @models.is_a?(Array)
        raise ArgumentError, "Models must be an array"
      end
      
      # Validate each model
      @models.each do |model|
        unless model.is_a?(Hash) && model[:name]
          raise ArgumentError, "Each model must be a hash with at least a name key"
        end
        
        # Ensure attributes is an array if present
        if model[:attributes] && !model[:attributes].is_a?(Array)
          raise ArgumentError, "Model attributes must be an array"
        end
      end
      
      # Validate batch jobs if present
      if @batch_jobs && !@batch_jobs.is_a?(Array)
        raise ArgumentError, "Batch jobs must be an array"
      end
    end
    
    def get_configuration
      {
        python_path: @python_path,
        framework_type: @framework_type,
        database_type: @database_type,
        models: @models,
        api_features: @api_features,
        batch_jobs: @batch_jobs
      }
    end
  end
end 