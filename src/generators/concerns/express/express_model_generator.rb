module Tenant
  module ExpressModelGenerator
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
    
    private
    
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
            allowNull: false#{attr.name == 'email' ? ',\n            unique: true' : ''}
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
  end
end 