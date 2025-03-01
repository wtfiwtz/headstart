require_relative '../../base'
require_relative '../../concerns/logging'
require_relative '../../concerns/python/configuration_handler'
require_relative '../../concerns/python/package_manager'
require_relative '../../concerns/python/application_structure_handler'
require_relative '../../concerns/python/model_generator'
require_relative '../../concerns/python/controller_generator'
require_relative '../../concerns/python/route_generator'
require_relative '../../concerns/python/api_features_handler'
require_relative '../../concerns/python/celery_handler'

module Tenant
  module Frameworks
    module Python
      class PythonGenerator < Tenant::BaseGenerator
        include Tenant::Logging
        include Tenant::PythonConfigurationHandler
        include Tenant::PythonPackageManager
        include Tenant::PythonApplicationStructureHandler
        include Tenant::PythonModelGenerator
        include Tenant::PythonControllerGenerator
        include Tenant::PythonRouteGenerator
        include Tenant::PythonApiFeaturesHandler
        include Tenant::PythonCeleryHandler
        
        attr_accessor :configuration, :models
        
        def initialize
          @models = []
          @configuration = {}
          
          # Ensure templates directory exists
          FileUtils.mkdir_p @templates_path
          
          log_info("Initialized PythonGenerator")
        end
        
        def models(models)
          @models = models
          log_info("Models set: #{@models.map(&:name).join(', ')}")
          self
        end
        
        def configuration(config)
          @configuration = config
          self
        end
        
        def apply_configuration
          @python_path = @configuration[:python_path] || './out/python_app'
          @framework_type = @configuration[:framework_type] || :fastapi
          @database_type = @configuration[:database_type] || :sqlalchemy
          @app_path = @python_path
          @config = @configuration
          
          # Initialize API features configuration
          initialize_api_features_config
          
          # Initialize Celery configuration if batch jobs are defined
          initialize_celery_config if @configuration[:batch_jobs]
          
          self
        end
        
        def execute
          with_error_handling do
            log_info("Executing Python generator")
            
            # Setup target directory
            setup_target
            
            # Create Python application structure
            create_python_app
            
            # Generate models
            generate_models
            
            # Generate controllers
            generate_controllers
            
            # Generate routes
            generate_routes
            
            # Generate API features
            generate_api_features
            
            # Generate Celery setup if batch jobs are defined
            generate_celery_setup if @configuration[:batch_jobs]
            
            log_info("Python application generated successfully at #{@python_path}")
          end
        end
        
        private
        
        def with_error_handling
          yield
        rescue StandardError => e
          log_error("Error generating Python application: #{e.message}")
          log_error(e.backtrace.join("\n"))
          raise e
        end
      end
    end
  end
end 