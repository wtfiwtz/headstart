require_relative '../../base'
require_relative '../../concerns/logging'
require_relative '../../concerns/express/configuration_handler'
require_relative '../../concerns/express/package_manager'
require_relative '../../concerns/express/database_handler'
require_relative '../../concerns/express/structure_generator'
require_relative '../../concerns/express/template_handler'
require_relative '../../concerns/express/express_model_generator'
require_relative '../../concerns/express/express_controller_generator'
require_relative '../../concerns/express/express_route_generator'
require_relative '../../concerns/express_app_structure_generator'
require_relative '../../concerns/environment_config_generator'
require_relative '../../concerns/express/api_features_handler'
require_relative '../../concerns/express/bullmq_handler'

module Tenant
  module Frameworks
    module Node
      class ExpressGenerator < Tenant::BaseGenerator
        include Tenant::Logging
        include Tenant::ExpressConfigurationHandler
        include Tenant::ExpressPackageManager
        include Tenant::ExpressDatabaseHandler
        include Tenant::ExpressStructureGenerator
        include Tenant::ExpressTemplateHandler
        include Tenant::ExpressModelGenerator
        include Tenant::ExpressControllerGenerator
        include Tenant::ExpressRouteGenerator
        include Tenant::ExpressAppStructureGenerator
        include Tenant::EnvironmentConfigGenerator
        include Tenant::ExpressApiFeaturesHandler
        include Tenant::ExpressBullMQHandler
        
        attr_accessor :configuration, :models, :language
        
        def initialize
          @express_path = nil
          @templates_path = File.join(File.dirname(__FILE__), '..', '..', '..', 'templates', 'express')
          @configuration = {}
          @models = []
          @language = 'javascript' # Default to JavaScript
          
          # Ensure templates directory exists
          FileUtils.mkdir_p(@templates_path)
          
          log_info("Initializing Express.js generator")
        end
        
        def apply_configuration(config)
          initialize_configuration(config)
          validate_configuration
          
          # Set language from configuration or default to JavaScript
          @language = config[:language].to_s.downcase if config[:language]
          log_info("Using language: #{@language}")
          
          # Initialize BullMQ configuration if batch jobs are defined
          initialize_bullmq_config(config) if config[:batch_jobs]
          
          log_info("Configuration applied")
        end
        
        def models
          @models = @configuration[:models] || []
          log_info("Models: #{@models.map { |m| m['name'] }.join(', ')}")
          @models
        end
        
        def execute
          log_info("Executing Express.js generator")
          
          # Setup target directory
          setup_target
          
          # Create Express.js application
          create_directory_structure(@database_type)
          create_app_js(@database_type)
          create_middleware_files
          
          # Generate database-specific files
          generate_database_files(@database_type) if respond_to?(:generate_database_files)
          
          # Create package.json
          create_package_json(@database_type)
          
          # Generate models, controllers, and routes
          generate_models
          generate_controllers
          generate_routes
          
          # Generate API features if enabled
          generate_api_features if @configuration[:api_features]
          
          # Generate BullMQ setup if batch jobs are defined
          generate_bullmq_setup if @configuration[:batch_jobs]
          
          log_info("Express.js application generated successfully at #{@express_path}")
        end
        
        def setup_target
          # Create target directory if it doesn't exist
          FileUtils.mkdir_p(@express_path) unless Dir.exist?(@express_path)
        end
        
        private
        
        def create_directory_structure(db_type)
          # Create basic directory structure
          %w[models controllers routes views public config].each do |dir|
            FileUtils.mkdir_p("#{@express_path}/#{dir}")
          end
          
          # Create .env file with appropriate database connection string
          env_content = "PORT=3000\n"
          
          case db_type.to_s.downcase
          when 'sequelize', 'sql', 'mysql', 'postgres', 'postgresql'
            dialect = db_type.to_s.downcase == 'mysql' ? 'mysql' : 'postgres'
            env_content += "DATABASE_URL=#{dialect}://postgres:postgres@localhost:5432/express_app_development\n"
          when 'prisma'
            env_content += "DATABASE_URL=postgresql://postgres:postgres@localhost:5432/express_app_development\n"
          else # Default to MongoDB
            env_content += "MONGODB_URI=mongodb://localhost:27017/express-app\n"
          end
          
          File.write("#{@express_path}/.env", env_content)
          
          # Create .gitignore
          File.write("#{@express_path}/.gitignore", "node_modules\n.env\n")
          
          # Create README.md with database-specific information
          readme_content = "# Express.js Application\n\nGenerated by Tenant\n\n"
          
          case db_type.to_s.downcase
          when 'sequelize', 'sql', 'mysql', 'postgres', 'postgresql'
            readme_content += "## Database\n\nThis application uses Sequelize ORM with "
            readme_content += (db_type.to_s.downcase == 'mysql' ? "MySQL" : "PostgreSQL")
            readme_content += ".\n\n"
          when 'prisma'
            readme_content += "## Database\n\nThis application uses Prisma ORM with PostgreSQL.\n\n"
          else # Default to MongoDB
            readme_content += "## Database\n\nThis application uses MongoDB with Mongoose ODM.\n\n"
          end
          
          readme_content += "## Getting Started\n\n"
          readme_content += "1. Install dependencies: `npm install`\n"
          readme_content += "2. Set up your database connection in `.env`\n"
          
          if db_type.to_s.downcase == 'prisma'
            readme_content += "3. Generate Prisma client: `npx prisma generate`\n"
            readme_content += "4. Run migrations: `npx prisma migrate dev`\n"
          elsif ['sequelize', 'sql', 'mysql', 'postgres', 'postgresql'].include?(db_type.to_s.downcase)
            readme_content += "3. Run migrations: `npx sequelize-cli db:migrate`\n"
          end
          
          readme_content += "#{db_type.to_s.downcase == 'prisma' || ['sequelize', 'sql', 'mysql', 'postgres', 'postgresql'].include?(db_type.to_s.downcase) ? '5' : '3'}. Start the server: `npm run dev`\n"
          
          File.write("#{@express_path}/README.md", readme_content)
        end
        
        def create_app_js(db_type)
          # Common imports and setup
          common_setup = <<~JS
            const express = require('express');
            const bodyParser = require('body-parser');
            require('dotenv').config();

            const app = express();
            const PORT = process.env.PORT || 3000;

            // Middleware
            app.use(bodyParser.json());
            app.use(bodyParser.urlencoded({ extended: true }));
            app.use(express.static('public'));
          JS
          
          # Database-specific imports and connection setup
          db_setup = case db_type.to_s.downcase
          when 'sequelize', 'sql', 'mysql', 'postgres', 'postgresql'
            <<~JS
              // Database connection (Sequelize)
              const sequelize = require('./models/index');
              
              sequelize.authenticate()
                .then(() => console.log('Connected to the database via Sequelize'))
                .catch(err => console.error('Unable to connect to the database:', err));
            JS
          when 'prisma'
            <<~JS
              // Database connection (Prisma)
              const { PrismaClient } = require('@prisma/client');
              const prisma = new PrismaClient();
              
              // Make Prisma Client available globally
              global.prisma = prisma;
              
              // Connect to the database
              async function connectPrisma() {
                try {
                  await prisma.$connect();
                  console.log('Connected to the database via Prisma');
                } catch (error) {
                  console.error('Unable to connect to the database:', error);
                  process.exit(1);
                }
              }
              
              connectPrisma();
            JS
          else # Default to MongoDB
            <<~JS
              // Database connection (MongoDB)
              const mongoose = require('mongoose');
              
              mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/express-app')
                .then(() => console.log('Connected to MongoDB'))
                .catch(err => console.error('Could not connect to MongoDB', err));
            JS
          end
          
          # Common routes and server startup
          common_end = <<~JS
            // Routes
            app.get('/', (req, res) => {
              res.send('Welcome to the Express.js application!');
            });

            // Start server
            app.listen(PORT, () => {
              console.log(`Server is running on port ${PORT}`);
            });
          JS
          
          # Combine all parts
          app_js_content = [common_setup, db_setup, common_end].join("\n\n")
          
          File.write("#{@express_path}/app.js", app_js_content)
        end
        
        def generate_models
          log_info("Generating models for #{@models.length} models")
          
          # Determine which database to use based on configuration
          db_type = @configuration&.database_type || 'mongodb'
          
          # For Prisma, update the schema file with all models at once
          if db_type.to_s.downcase == 'prisma'
            generate_prisma_models
          else
            # For Mongoose and Sequelize, generate individual model files
            @models.each do |model|
              generate_model(model)
            end
          end
        end
        
        def generate_model(model)
          log_info("Generating model for #{model.name}")
          
          # Determine which database to use based on configuration
          db_type = @configuration&.database_type || 'mongodb'
          
          case db_type.to_s.downcase
          when 'sequelize', 'sql', 'mysql', 'postgres', 'postgresql'
            generate_sequelize_model(model)
          when 'prisma'
            # Prisma models are generated in bulk in generate_prisma_models
            # This is a no-op for individual models
          else # Default to MongoDB
            generate_mongoose_model(model)
          end
        end
        
        def generate_mongoose_model(model)
          model_content = <<~JS
            const mongoose = require('mongoose');
            const Schema = mongoose.Schema;

            const #{model.name.camelize}Schema = new Schema({
              #{generate_schema_fields(model)}
            }, {
              timestamps: true
            });

            #{generate_model_methods(model)}

            module.exports = mongoose.model('#{model.name.camelize}', #{model.name.camelize}Schema);
          JS
          
          File.write("#{@express_path}/models/#{model.name.underscore}.js", model_content)
        end
        
        def generate_sequelize_model(model)
          model_content = <<~JS
            const { DataTypes } = require('sequelize');
            const sequelize = require('./index');

            const #{model.name.camelize} = sequelize.define('#{model.name.underscore}', {
              #{generate_sequelize_fields(model)}
            }, {
              timestamps: true
            });

            #{generate_sequelize_associations(model)}

            module.exports = #{model.name.camelize};
          JS
          
          File.write("#{@express_path}/models/#{model.name.underscore}.js", model_content)
        end
        
        def generate_prisma_models
          log_info("Generating Prisma models")
          
          # Read the existing schema file
          schema_path = "#{@express_path}/prisma/schema.prisma"
          schema_content = File.read(schema_path)
          
          # Generate model definitions
          model_definitions = @models.map do |model|
            generate_prisma_model_definition(model)
          end.join("\n\n")
          
          # Add model definitions to the schema
          updated_schema = schema_content.gsub(/\/\/ Models will be generated here during the model generation phase/, model_definitions)
          
          # Write the updated schema
          File.write(schema_path, updated_schema)
        end
        
        def generate_prisma_model_definition(model)
          fields = model.attributes.map do |attr|
            field_type = prisma_type_for(attr.type)
            required = ['name', 'title', 'email'].include?(attr.name)
            
            if attr.name == 'id'
              "  id    Int     @id @default(autoincrement())"
            elsif required
              "  #{attr.name}  #{field_type}  @map(\"#{attr.name}\") #{attr.name == 'email' ? '@unique' : ''}"
            else
              "  #{attr.name}  #{field_type}?"
            end
          end
          
          # Add timestamps
          fields << "  createdAt DateTime @default(now()) @map(\"created_at\")"
          fields << "  updatedAt DateTime @updatedAt @map(\"updated_at\")"
          
          # Build the model definition
          <<~PRISMA
            model #{model.name.camelize} {
            #{fields.join("\n")}
            
              @@map("#{model.name.underscore.pluralize}")
            }
          PRISMA
        end
        
        def generate_sequelize_fields(model)
          model.attributes.map do |attr|
            field_type = sequelize_type_for(attr.type)
            required = ['name', 'title', 'email'].include?(attr.name)
            
            if required
              "#{attr.name}: { 
                type: DataTypes.#{field_type}, 
                allowNull: false#{attr.name == 'email' ? ',\n                unique: true' : ''}
              }"
            else
              "#{attr.name}: { 
                type: DataTypes.#{field_type}
              }"
            end
          end.join(",\n      ")
        end
        
        def generate_sequelize_associations(model)
          # This is a placeholder for generating associations
          # In a real implementation, this would analyze relationships between models
          "// Define associations here if needed\n"
        end
        
        def sequelize_type_for(type)
          case type.to_s
          when 'string'
            'STRING'
          when 'text'
            'TEXT'
          when 'integer'
            'INTEGER'
          when 'float', 'decimal'
            'FLOAT'
          when 'boolean'
            'BOOLEAN'
          when 'date'
            'DATEONLY'
          when 'datetime'
            'DATE'
          else
            'STRING'
          end
        end
        
        def prisma_type_for(type)
          case type.to_s
          when 'string'
            'String'
          when 'text'
            'String'
          when 'integer'
            'Int'
          when 'float', 'decimal'
            'Float'
          when 'boolean'
            'Boolean'
          when 'date', 'datetime'
            'DateTime'
          else
            'String'
          end
        end
        
        def generate_schema_fields(model)
          model.attributes.map do |attr|
            field_type = mongoose_type_for(attr.type)
            required = ['name', 'title', 'email'].include?(attr.name)
            
            if required
              "#{attr.name}: { type: #{field_type}, required: true }"
            else
              "#{attr.name}: #{field_type}"
            end
          end.join(",\n  ")
        end
        
        def mongoose_type_for(type)
          case type.to_s
          when 'string'
            'String'
          when 'text'
            'String'
          when 'integer'
            'Number'
          when 'float', 'decimal'
            'Number'
          when 'boolean'
            'Boolean'
          when 'date'
            'Date'
          when 'datetime'
            'Date'
          else
            'String'
          end
        end
        
        def generate_model_methods(model)
          methods = []
          
          # Add virtual for URL
          methods << <<~JS
            #{model.name.camelize}Schema.virtual('url').get(function() {
              return `/#{model.name.underscore.pluralize}/${this._id}`;
            });
          JS
          
          methods.join("\n\n")
        end
        
        def generate_controllers
          log_info("Generating controllers for #{@models.length} models")
          
          @models.each do |model|
            generate_controller(model)
          end
        end
        
        def generate_controller(model)
          log_info("Generating controller for #{model.name}")
          
          # Determine which database to use based on configuration
          db_type = @configuration&.database_type || 'mongodb'
          
          case db_type.to_s.downcase
          when 'sequelize', 'sql', 'mysql', 'postgres', 'postgresql'
            generate_sequelize_controller(model)
          when 'prisma'
            generate_prisma_controller(model)
          else # Default to MongoDB
            generate_mongoose_controller(model)
          end
        end
        
        def generate_mongoose_controller(model)
          controller_content = <<~JS
            const #{model.name.camelize} = require('../models/#{model.name.underscore}');

            // Get all #{model.name.pluralize}
            exports.get#{model.name.pluralize.camelize} = async (req, res) => {
              try {
                const #{model.name.underscore.pluralize} = await #{model.name.camelize}.find();
                res.status(200).json(#{model.name.underscore.pluralize});
              } catch (error) {
                res.status(500).json({ message: error.message });
              }
            };

            // Get a single #{model.name}
            exports.get#{model.name.camelize} = async (req, res) => {
              try {
                const #{model.name.underscore} = await #{model.name.camelize}.findById(req.params.id);
                if (!#{model.name.underscore}) {
                  return res.status(404).json({ message: '#{model.name} not found' });
                }
                res.status(200).json(#{model.name.underscore});
              } catch (error) {
                res.status(500).json({ message: error.message });
              }
            };

            // Create a new #{model.name}
            exports.create#{model.name.camelize} = async (req, res) => {
              try {
                const #{model.name.underscore} = new #{model.name.camelize}(req.body);
                const new#{model.name.camelize} = await #{model.name.underscore}.save();
                res.status(201).json(new#{model.name.camelize});
              } catch (error) {
                res.status(400).json({ message: error.message });
              }
            };

            // Update a #{model.name}
            exports.update#{model.name.camelize} = async (req, res) => {
              try {
                const updated#{model.name.camelize} = await #{model.name.camelize}.findByIdAndUpdate(
                  req.params.id,
                  req.body,
                  { new: true }
                );
                if (!updated#{model.name.camelize}) {
                  return res.status(404).json({ message: '#{model.name} not found' });
                }
                res.status(200).json(updated#{model.name.camelize});
              } catch (error) {
                res.status(400).json({ message: error.message });
              }
            };

            // Delete a #{model.name}
            exports.delete#{model.name.camelize} = async (req, res) => {
              try {
                const #{model.name.underscore} = await #{model.name.camelize}.findByIdAndDelete(req.params.id);
                if (!#{model.name.underscore}) {
                  return res.status(404).json({ message: '#{model.name} not found' });
                }
                res.status(200).json({ message: '#{model.name} deleted successfully' });
              } catch (error) {
                res.status(500).json({ message: error.message });
              }
            };
          JS
          
          File.write("#{@express_path}/controllers/#{model.name.underscore}_controller.js", controller_content)
        end
        
        def generate_sequelize_controller(model)
          controller_content = <<~JS
            const #{model.name.camelize} = require('../models/#{model.name.underscore}');

            // Get all #{model.name.pluralize}
            exports.get#{model.name.pluralize.camelize} = async (req, res) => {
              try {
                const #{model.name.underscore.pluralize} = await #{model.name.camelize}.findAll();
                res.status(200).json(#{model.name.underscore.pluralize});
              } catch (error) {
                res.status(500).json({ message: error.message });
              }
            };

            // Get a single #{model.name}
            exports.get#{model.name.camelize} = async (req, res) => {
              try {
                const #{model.name.underscore} = await #{model.name.camelize}.findByPk(req.params.id);
                if (!#{model.name.underscore}) {
                  return res.status(404).json({ message: '#{model.name} not found' });
                }
                res.status(200).json(#{model.name.underscore});
              } catch (error) {
                res.status(500).json({ message: error.message });
              }
            };

            // Create a new #{model.name}
            exports.create#{model.name.camelize} = async (req, res) => {
              try {
                const new#{model.name.camelize} = await #{model.name.camelize}.create(req.body);
                res.status(201).json(new#{model.name.camelize});
              } catch (error) {
                res.status(400).json({ message: error.message });
              }
            };

            // Update a #{model.name}
            exports.update#{model.name.camelize} = async (req, res) => {
              try {
                const [updated] = await #{model.name.camelize}.update(req.body, {
                  where: { id: req.params.id }
                });
                
                if (updated) {
                  const updated#{model.name.camelize} = await #{model.name.camelize}.findByPk(req.params.id);
                  res.status(200).json(updated#{model.name.camelize});
                } else {
                  return res.status(404).json({ message: '#{model.name} not found' });
                }
              } catch (error) {
                res.status(400).json({ message: error.message });
              }
            };

            // Delete a #{model.name}
            exports.delete#{model.name.camelize} = async (req, res) => {
              try {
                const deleted = await #{model.name.camelize}.destroy({
                  where: { id: req.params.id }
                });
                
                if (deleted) {
                  res.status(200).json({ message: '#{model.name} deleted successfully' });
                } else {
                  return res.status(404).json({ message: '#{model.name} not found' });
                }
              } catch (error) {
                res.status(500).json({ message: error.message });
              }
            };
          JS
          
          File.write("#{@express_path}/controllers/#{model.name.underscore}_controller.js", controller_content)
        end
        
        def generate_prisma_controller(model)
          controller_content = <<~JS
            // Get all #{model.name.pluralize}
            exports.get#{model.name.pluralize.camelize} = async (req, res) => {
              try {
                const #{model.name.underscore.pluralize} = await prisma.#{model.name.camelize}.findMany();
                res.status(200).json(#{model.name.underscore.pluralize});
              } catch (error) {
                res.status(500).json({ message: error.message });
              }
            };

            // Get a single #{model.name}
            exports.get#{model.name.camelize} = async (req, res) => {
              try {
                const #{model.name.underscore} = await prisma.#{model.name.camelize}.findUnique({
                  where: { id: parseInt(req.params.id) }
                });
                
                if (!#{model.name.underscore}) {
                  return res.status(404).json({ message: '#{model.name} not found' });
                }
                
                res.status(200).json(#{model.name.underscore});
              } catch (error) {
                res.status(500).json({ message: error.message });
              }
            };

            // Create a new #{model.name}
            exports.create#{model.name.camelize} = async (req, res) => {
              try {
                const new#{model.name.camelize} = await prisma.#{model.name.camelize}.create({
                  data: req.body
                });
                
                res.status(201).json(new#{model.name.camelize});
              } catch (error) {
                res.status(400).json({ message: error.message });
              }
            };

            // Update a #{model.name}
            exports.update#{model.name.camelize} = async (req, res) => {
              try {
                const updated#{model.name.camelize} = await prisma.#{model.name.camelize}.update({
                  where: { id: parseInt(req.params.id) },
                  data: req.body
                });
                
                res.status(200).json(updated#{model.name.camelize});
              } catch (error) {
                if (error.code === 'P2025') {
                  return res.status(404).json({ message: '#{model.name} not found' });
                }
                res.status(400).json({ message: error.message });
              }
            };

            // Delete a #{model.name}
            exports.delete#{model.name.camelize} = async (req, res) => {
              try {
                await prisma.#{model.name.camelize}.delete({
                  where: { id: parseInt(req.params.id) }
                });
                
                res.status(200).json({ message: '#{model.name} deleted successfully' });
              } catch (error) {
                if (error.code === 'P2025') {
                  return res.status(404).json({ message: '#{model.name} not found' });
                }
                res.status(500).json({ message: error.message });
              }
            };
          JS
          
          File.write("#{@express_path}/controllers/#{model.name.underscore}_controller.js", controller_content)
        end
        
        def generate_routes
          log_info("Generating routes for #{@models.length} models")
          
          # Generate individual route files
          @models.each do |model|
            generate_route(model)
          end
          
          # Update app.js to include routes
          update_app_js_with_routes
        end
        
        def generate_route(model)
          log_info("Generating route for #{model.name}")
          
          route_content = <<~JS
            const express = require('express');
            const router = express.Router();
            const #{model.name.underscore}Controller = require('../controllers/#{model.name.underscore}_controller');

            // Get all #{model.name.pluralize}
            router.get('/', #{model.name.underscore}Controller.get#{model.name.pluralize.camelize});

            // Get a single #{model.name}
            router.get('/:id', #{model.name.underscore}Controller.get#{model.name.camelize});

            // Create a new #{model.name}
            router.post('/', #{model.name.underscore}Controller.create#{model.name.camelize});

            // Update a #{model.name}
            router.put('/:id', #{model.name.underscore}Controller.update#{model.name.camelize});

            // Delete a #{model.name}
            router.delete('/:id', #{model.name.underscore}Controller.delete#{model.name.camelize});

            module.exports = router;
          JS
          
          File.write("#{@express_path}/routes/#{model.name.underscore}_routes.js", route_content)
        end
        
        def update_app_js_with_routes
          # Read the existing app.js
          app_js_path = "#{@express_path}/app.js"
          app_js_content = File.read(app_js_path)
          
          # Generate route imports
          route_imports = @models.map do |model|
            "const #{model.name.underscore}Routes = require('./routes/#{model.name.underscore}_routes');"
          end.join("\n")
          
          # Generate route usage
          route_usage = @models.map do |model|
            "app.use('/api/#{model.name.underscore.pluralize}', #{model.name.underscore}Routes);"
          end.join("\n")
          
          # Insert route imports after the last require statement
          updated_content = app_js_content.gsub(/require\([^\)]+\);(?![\s\S]*require\([^\)]+\);)/, "\\0\n\n// Route imports\n#{route_imports}")
          
          # Insert route usage before the server start
          updated_content = updated_content.gsub(/app\.listen/, "// API Routes\n#{route_usage}\n\n// Start server\napp.listen")
          
          # Write the updated app.js
          File.write(app_js_path, updated_content)
        end
        
        def generate_views
          # Express.js applications often use client-side frameworks or APIs
          # This is a placeholder for view generation if needed
          log_info("View generation not implemented for Express.js")
        end
        
        def generate_api_features
          # Implement API features generation logic here
          log_info("API features generation not implemented for Express.js")
        end
        
        def generate_bullmq_setup
          # Implement BullMQ setup generation logic here
          log_info("BullMQ setup generation not implemented for Express.js")
        end
        
        def with_error_handling
          yield
        rescue StandardError => e
          log_error("Error during Express.js application generation: #{e.message}")
          log_error(e.backtrace.join("\n"))
          raise
        end
      end
    end
  end
end 