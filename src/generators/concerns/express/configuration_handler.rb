module Tenant
  module ExpressConfigurationHandler
    def initialize_configuration(config)
      @config = config
      @express_path = config[:express_path] || "express-app"
      @database_type = config[:database_type] || "mongodb"
      @models = config[:models] || []
    end
    
    def validate_configuration
      # Ensure express_path is set
      unless @express_path
        raise ArgumentError, "Express path must be specified in configuration"
      end
      
      # Ensure database_type is valid
      valid_db_types = ["mongodb", "mongoose", "sequelize", "prisma", "sql", "mysql", "postgres", "postgresql"]
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
    end
    
    def get_configuration
      {
        express_path: @express_path,
        database_type: @database_type,
        models: @models
      }
    end
  end
end 