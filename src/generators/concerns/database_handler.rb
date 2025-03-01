module Tenant
  module DatabaseHandler
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
    
    def get_database_env_content(db_type)
      case db_type.to_s.downcase
      when 'sequelize', 'sql', 'mysql', 'postgres', 'postgresql'
        dialect = db_type.to_s.downcase == 'mysql' ? 'mysql' : 'postgres'
        "DATABASE_URL=#{dialect}://postgres:postgres@localhost:5432/express_app_development\n"
      when 'prisma'
        "DATABASE_URL=postgresql://postgres:postgres@localhost:5432/express_app_development\n"
      else # Default to MongoDB
        "MONGODB_URI=mongodb://localhost:27017/express-app\n"
      end
    end
    
    def get_database_readme_content(db_type)
      case db_type.to_s.downcase
      when 'sequelize', 'sql', 'mysql', 'postgres', 'postgresql'
        "## Database\n\nThis application uses Sequelize ORM with " +
        (db_type.to_s.downcase == 'mysql' ? "MySQL" : "PostgreSQL") +
        ".\n\n"
      when 'prisma'
        "## Database\n\nThis application uses Prisma ORM with PostgreSQL.\n\n"
      else # Default to MongoDB
        "## Database\n\nThis application uses MongoDB with Mongoose ODM.\n\n"
      end
    end
    
    def get_database_setup_steps(db_type)
      if db_type.to_s.downcase == 'prisma'
        "3. Generate Prisma client: `npx prisma generate`\n" +
        "4. Run migrations: `npx prisma migrate dev`\n"
      elsif ['sequelize', 'sql', 'mysql', 'postgres', 'postgresql'].include?(db_type.to_s.downcase)
        "3. Run migrations: `npx sequelize-cli db:migrate`\n"
      else
        ""
      end
    end
    
    def get_database_connection_code(db_type)
      case db_type.to_s.downcase
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
    end
  end
end 