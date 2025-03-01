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
        
        attr_accessor :configuration, :models
        
        def initialize
          @express_path = "#{__dir__}/../../../../out/express_app"
          @templates_path = "#{__dir__}/../../../../templates/express"
          @configuration = nil
          @models = []
          
          # Ensure templates directory exists
          FileUtils.mkdir_p @templates_path
          
          log_info("Initialized ExpressGenerator with express_path: #{@express_path}")
          log_info("Templates path: #{@templates_path}")
        end
        
        def apply_configuration(configuration)
          initialize_configuration(configuration)
          validate_configuration
          log_info("Configuration applied")
          self
        end
        
        def models(models_array)
          @models = models_array
          log_info("Models set: #{models_array.map(&:name).join(', ')}")
          self
        end
        
        def execute
          with_error_handling do
            log_info("Starting Express.js application generation")
            
            # Setup the target directory
            setup_target
            
            # Generate models
            generate_models
            
            # Generate controllers
            generate_controllers
            
            # Generate routes
            generate_routes
            
            # Generate utility files
            generate_utils
            generate_error_classes
            
            # Generate API features
            generate_api_features
            
            log_info("Express.js application generation completed successfully")
          end
        end
        
        private
        
        def setup_target
          return if Dir.exist?(@express_path)
          
          FileUtils.mkdir_p @express_path
          
          # Create basic Express.js application structure
          create_express_app
        end
        
        def create_express_app
          log_info("Creating Express.js application")
          
          # Create package.json
          create_package_json(@database_type)
          
          # Create app.js
          create_app_js(@database_type)
          
          # Create basic directory structure
          create_directory_structure(@database_type)
          
          # Create middleware files
          create_middleware_files
          
          # Initialize database if needed
          case @database_type.to_s.downcase
          when 'prisma'
            initialize_prisma
          when 'sequelize', 'sql', 'mysql', 'postgres', 'postgresql'
            initialize_sequelize
          end
          
          # Install dependencies if requested
          install_dependencies if @config[:install_dependencies]
        end
        
        def create_package_json(db_type)
          # Base dependencies that are always included
          dependencies = {
            express: "^4.18.2",
            "body-parser": "^1.20.2",
            "dotenv": "^16.0.3"
          }
          
          # Add database-specific dependencies
          case db_type.to_s.downcase
          when 'sequelize', 'sql', 'mysql', 'postgres', 'postgresql'
            dependencies.merge!({
              sequelize: "^6.32.0",
              pg: "^8.11.0",        # PostgreSQL driver
              mysql2: "^3.4.0",     # MySQL driver
              "sequelize-cli": "^6.6.1"
            })
          when 'prisma'
            dependencies.merge!({
              "@prisma/client": "^4.15.0"
            })
          else # Default to MongoDB
            dependencies.merge!({
              mongoose: "^7.0.0"
            })
          end
          
          package_json = {
            name: "express-app",
            version: "1.0.0",
            description: "Express.js application generated by Tenant",
            main: "app.js",
            scripts: {
              start: "node app.js",
              dev: "nodemon app.js"
            },
            dependencies: dependencies,
            devDependencies: {
              nodemon: "^2.0.22"
            }
          }
          
          # Add Prisma dev dependency if using Prisma
          if db_type.to_s.downcase == 'prisma'
            package_json[:devDependencies]["prisma"] = "^4.15.0"
          end
          
          File.write("#{@express_path}/package.json", JSON.pretty_generate(package_json))
          
          # Create additional files for specific database types
          case db_type.to_s.downcase
          when 'prisma'
            create_prisma_schema
          when 'sequelize', 'sql', 'mysql', 'postgres', 'postgresql'
            create_sequelize_config
          end
        end
        
        def create_prisma_schema
          prisma_schema = <<~PRISMA
            // This is your Prisma schema file,
            // learn more about it in the docs: https://pris.ly/d/prisma-schema

            generator client {
              provider = "prisma-client-js"
            }

            datasource db {
              provider = "postgresql" // Change to "mysql" or "sqlite" if needed
              url      = env("DATABASE_URL")
            }
            
            // Models will be generated here during the model generation phase
          PRISMA
          
          FileUtils.mkdir_p("#{@express_path}/prisma")
          File.write("#{@express_path}/prisma/schema.prisma", prisma_schema)
        end
        
        def create_sequelize_config
          sequelize_config = {
            development: {
              username: "postgres",
              password: "postgres",
              database: "express_app_development",
              host: "127.0.0.1",
              dialect: "postgres" # Can be changed to mysql, sqlite, etc.
            },
            test: {
              username: "postgres",
              password: "postgres",
              database: "express_app_test",
              host: "127.0.0.1",
              dialect: "postgres"
            },
            production: {
              use_env_variable: "DATABASE_URL",
              dialect: "postgres"
            }
          }
          
          FileUtils.mkdir_p("#{@express_path}/config")
          File.write("#{@express_path}/config/config.json", JSON.pretty_generate(sequelize_config))
          
          # Create Sequelize initialization file
          sequelize_init = <<~JS
            const { Sequelize } = require('sequelize');
            const env = process.env.NODE_ENV || 'development';
            const config = require('./config/config.json')[env];
            
            let sequelize;
            if (config.use_env_variable) {
              sequelize = new Sequelize(process.env[config.use_env_variable], config);
            } else {
              sequelize = new Sequelize(
                config.database,
                config.username,
                config.password,
                config
              );
            }
            
            module.exports = sequelize;
          JS
          
          File.write("#{@express_path}/models/index.js", sequelize_init)
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