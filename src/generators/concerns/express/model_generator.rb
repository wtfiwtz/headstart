module Tenant
  module ExpressModelGenerator
    def generate_models
      @models.each do |model|
        generate_model(model)
      end
    end

    def generate_model(model)
      model_name = model['name']
      attributes = model['attributes'] || []
      
      # Determine file extension and path based on language
      file_ext = @language.to_s.downcase == "typescript" ? "ts" : "js"
      model_path = @language.to_s.downcase == "typescript" ? "#{@express_path}/src/models" : "#{@express_path}/models"
      
      case @database_type.to_s.downcase
      when 'sequelize', 'sql', 'mysql', 'postgres', 'postgresql'
        generate_sequelize_model(model_name, attributes, model_path, file_ext)
      when 'prisma'
        generate_prisma_model(model_name, attributes)
      else # Default to MongoDB
        generate_mongoose_model(model_name, attributes, model_path, file_ext)
      end
    end

    private

    def generate_sequelize_model(model_name, attributes, model_path, file_ext)
      model_file = "#{model_path}/#{model_name.downcase}.#{file_ext}"
      
      if @language.to_s.downcase == "typescript"
        model_content = <<~TS
          import { Model, DataTypes, Optional } from 'sequelize';
          import sequelize from '../utils/database';

          // Interface for #{model_name} attributes
          interface #{model_name}Attributes {
            id: number;
            #{attributes.map { |attr| "#{attr['name']}: #{get_typescript_type(attr['type'])};" }.join("\n            ")}
            createdAt?: Date;
            updatedAt?: Date;
          }

          // Interface for creation attributes (optional id)
          interface #{model_name}CreationAttributes extends Optional<#{model_name}Attributes, 'id'> {}

          // #{model_name} model class
          class #{model_name} extends Model<#{model_name}Attributes, #{model_name}CreationAttributes> implements #{model_name}Attributes {
            public id!: number;
            #{attributes.map { |attr| "public #{attr['name']}!: #{get_typescript_type(attr['type'])};" }.join("\n            ")}
            public readonly createdAt!: Date;
            public readonly updatedAt!: Date;
          }

          #{model_name}.init(
            {
              id: {
                type: DataTypes.INTEGER,
                autoIncrement: true,
                primaryKey: true,
              },
              #{attributes.map { |attr| "#{attr['name']}: {\n                type: DataTypes.#{get_sequelize_type(attr['type'])},\n                #{attr['required'] ? 'allowNull: false,' : ''}\n              }" }.join(",\n              ")}
            },
            {
              sequelize,
              modelName: '#{model_name}',
              tableName: '#{model_name.downcase}s',
            }
          );

          export default #{model_name};
        TS
      else
        model_content = <<~JS
          const { DataTypes } = require('sequelize');
          const sequelize = require('../utils/database');

          const #{model_name} = sequelize.define('#{model_name}', {
            id: {
              type: DataTypes.INTEGER,
              autoIncrement: true,
              primaryKey: true,
            },
            #{attributes.map { |attr| "#{attr['name']}: {\n              type: DataTypes.#{get_sequelize_type(attr['type'])},\n              #{attr['required'] ? 'allowNull: false,' : ''}\n            }" }.join(",\n            ")}
          }, {
            tableName: '#{model_name.downcase}s',
          });

          module.exports = #{model_name};
        JS
      end
      
      File.write(model_file, model_content)
      
      # Create database utility file if it doesn't exist
      create_database_util_file(file_ext)
    end

    def generate_mongoose_model(model_name, attributes, model_path, file_ext)
      model_file = "#{model_path}/#{model_name.downcase}.#{file_ext}"
      
      if @language.to_s.downcase == "typescript"
        model_content = <<~TS
          import mongoose, { Schema, Document } from 'mongoose';

          // Interface for #{model_name} document
          export interface I#{model_name} extends Document {
            #{attributes.map { |attr| "#{attr['name']}: #{get_typescript_type(attr['type'])};" }.join("\n            ")}
          }

          // #{model_name} schema
          const #{model_name.downcase}Schema = new Schema({
            #{attributes.map { |attr| "#{attr['name']}: {\n              type: #{get_mongoose_type(attr['type'])},\n              #{attr['required'] ? 'required: true,' : ''}\n            }" }.join(",\n            ")}
          }, {
            timestamps: true
          });

          // #{model_name} model
          const #{model_name} = mongoose.model<I#{model_name}>('#{model_name}', #{model_name.downcase}Schema);

          export default #{model_name};
        TS
      else
        model_content = <<~JS
          const mongoose = require('mongoose');
          const { Schema } = mongoose;

          const #{model_name.downcase}Schema = new Schema({
            #{attributes.map { |attr| "#{attr['name']}: {\n              type: #{get_mongoose_type(attr['type'])},\n              #{attr['required'] ? 'required: true,' : ''}\n            }" }.join(",\n            ")}
          }, {
            timestamps: true
          });

          const #{model_name} = mongoose.model('#{model_name}', #{model_name.downcase}Schema);

          module.exports = #{model_name};
        JS
      end
      
      File.write(model_file, model_content)
    end

    def create_database_util_file(file_ext)
      # Create database utility file for Sequelize
      db_util_path = @language.to_s.downcase == "typescript" ? "#{@express_path}/src/utils" : "#{@express_path}/utils"
      db_util_file = "#{db_util_path}/database.#{file_ext}"
      
      # Skip if file already exists
      return if File.exist?(db_util_file)
      
      if @language.to_s.downcase == "typescript"
        db_util_content = <<~TS
          import { Sequelize } from 'sequelize';
          import dotenv from 'dotenv';

          dotenv.config();

          const sequelize = new Sequelize(
            process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/express_app_development',
            {
              dialect: '#{@database_type.to_s.downcase == 'mysql' ? 'mysql' : 'postgres'}',
              logging: false,
            }
          );

          export default sequelize;
        TS
      else
        db_util_content = <<~JS
          const { Sequelize } = require('sequelize');
          require('dotenv').config();

          const sequelize = new Sequelize(
            process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/express_app_development',
            {
              dialect: '#{@database_type.to_s.downcase == 'mysql' ? 'mysql' : 'postgres'}',
              logging: false,
            }
          );

          module.exports = sequelize;
        JS
      end
      
      File.write(db_util_file, db_util_content)
    end

    # Helper methods for type conversion
    def get_typescript_type(type)
      case type.to_s.downcase
      when 'string', 'text', 'char', 'varchar'
        'string'
      when 'integer', 'int', 'number', 'float', 'decimal', 'double'
        'number'
      when 'boolean', 'bool'
        'boolean'
      when 'date', 'datetime', 'timestamp'
        'Date'
      when 'json', 'object'
        'Record<string, any>'
      when 'array'
        'any[]'
      else
        'any'
      end
    end

    def get_sequelize_type(type)
      case type.to_s.downcase
      when 'string', 'varchar', 'char'
        'STRING'
      when 'text'
        'TEXT'
      when 'integer', 'int'
        'INTEGER'
      when 'float', 'decimal', 'double'
        'FLOAT'
      when 'boolean', 'bool'
        'BOOLEAN'
      when 'date'
        'DATEONLY'
      when 'datetime', 'timestamp'
        'DATE'
      when 'json', 'object'
        'JSON'
      when 'array'
        'ARRAY(DataTypes.STRING)'
      else
        'STRING'
      end
    end

    def get_mongoose_type(type)
      case type.to_s.downcase
      when 'string', 'text', 'char', 'varchar'
        'String'
      when 'integer', 'int', 'number', 'float', 'decimal', 'double'
        'Number'
      when 'boolean', 'bool'
        'Boolean'
      when 'date', 'datetime', 'timestamp'
        'Date'
      when 'json', 'object'
        'Object'
      when 'array'
        '[Schema.Types.Mixed]'
      else
        'String'
      end
    end
  end
end 