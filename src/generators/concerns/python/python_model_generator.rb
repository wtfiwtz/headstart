module Tenant
  module PythonModelGenerator
    def generate_models
      log_info("Generating models for #{@models.length} models")
      
      # Generate models based on database type
      case @database_type.to_s.downcase
      when "sqlalchemy"
        generate_sqlalchemy_models
      when "mongodb"
        generate_mongodb_models
      when "pony"
        generate_pony_models
      when "peewee"
        generate_peewee_models
      when "django-orm"
        generate_django_models
      end
      
      # Generate schemas for all models
      generate_schemas
      
      log_info("Models generated")
    end
    
    def generate_sqlalchemy_models
      log_info("Generating SQLAlchemy models")
      
      # Create __init__.py
      File.write("#{@python_path}/app/models/__init__.py", "# Import models here\n")
      
      # Generate each model
      @models.each do |model|
        generate_sqlalchemy_model(model)
      end
    end
    
    def generate_sqlalchemy_model(model)
      model_name = model[:name]
      model_file = "#{@python_path}/app/models/#{model_name.downcase}.py"
      
      log_info("Generating SQLAlchemy model: #{model_name}")
      
      # Generate imports
      imports = <<~PYTHON
        from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, Float, Table
        from sqlalchemy.orm import relationship
        from datetime import datetime
        from app.db.database import Base
      PYTHON
      
      # Generate model class
      model_class = <<~PYTHON
        class #{model_name.capitalize}(Base):
            __tablename__ = "#{model_name.downcase}s"
            
            id = Column(Integer, primary_key=True, index=True)
            #{generate_sqlalchemy_fields(model)}
            #{generate_sqlalchemy_relationships(model)}
            created_at = Column(DateTime, default=datetime.utcnow)
            updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
            
            def __repr__(self):
                return f"<#{model_name.capitalize} {self.id}>"
      PYTHON
      
      # Write model file
      File.write(model_file, imports + "\n" + model_class)
      
      log_info("Generated SQLAlchemy model: #{model_name}")
    end
    
    def generate_sqlalchemy_fields(model)
      return "" unless model[:attributes]
      
      model[:attributes].map do |attr|
        name = attr[:name]
        type = attr[:type]
        nullable = attr[:nullable] || false
        unique = attr[:unique] || false
        index = attr[:index] || false
        
        "#{name} = Column(#{sqlalchemy_type_for(type)}, nullable=#{nullable}, unique=#{unique}, index=#{index})"
      end.join("\n    ")
    end
    
    def generate_sqlalchemy_relationships(model)
      return "" unless model[:associations]
      
      model[:associations].map do |assoc|
        kind = assoc[:kind]
        name = assoc[:name]
        
        case kind
        when "has_many"
          "#{name} = relationship(\"#{name.capitalize}\", back_populates=\"#{model[:name].downcase}\")"
        when "belongs_to"
          "#{name}_id = Column(Integer, ForeignKey(\"#{name.downcase}s.id\"))\n    #{name} = relationship(\"#{name.capitalize}\", back_populates=\"#{model[:name].downcase}s\")"
        when "has_one"
          "#{name} = relationship(\"#{name.capitalize}\", uselist=False, back_populates=\"#{model[:name].downcase}\")"
        else
          ""
        end
      end.join("\n    ")
    end
    
    def sqlalchemy_type_for(type)
      case type.to_s.downcase
      when "string"
        "String"
      when "text"
        "Text"
      when "integer"
        "Integer"
      when "float"
        "Float"
      when "decimal"
        "Float"
      when "boolean"
        "Boolean"
      when "datetime"
        "DateTime"
      when "date"
        "Date"
      when "time"
        "Time"
      when "json"
        "JSON"
      else
        "String"
      end
    end
    
    def generate_mongodb_models
      log_info("Generating MongoDB models")
      
      # Create __init__.py
      File.write("#{@python_path}/app/models/__init__.py", "# Import models here\n")
      
      # Generate each model
      @models.each do |model|
        generate_mongodb_model(model)
      end
    end
    
    def generate_mongodb_model(model)
      model_name = model[:name]
      model_file = "#{@python_path}/app/models/#{model_name.downcase}.py"
      
      log_info("Generating MongoDB model: #{model_name}")
      
      # Generate model class
      model_content = <<~PYTHON
        from datetime import datetime
        from typing import Optional, List
        from pydantic import BaseModel, Field
        from bson import ObjectId

        class PyObjectId(ObjectId):
            @classmethod
            def __get_validators__(cls):
                yield cls.validate

            @classmethod
            def validate(cls, v):
                if not ObjectId.is_valid(v):
                    raise ValueError("Invalid ObjectId")
                return ObjectId(v)

            @classmethod
            def __modify_schema__(cls, field_schema):
                field_schema.update(type="string")

        class #{model_name.capitalize}Model(BaseModel):
            id: PyObjectId = Field(default_factory=PyObjectId, alias="_id")
            #{generate_mongodb_fields(model)}
            created_at: datetime = Field(default_factory=datetime.utcnow)
            updated_at: datetime = Field(default_factory=datetime.utcnow)
            
            class Config:
                allow_population_by_field_name = True
                arbitrary_types_allowed = True
                json_encoders = {ObjectId: str}
                schema_extra = {
                    "example": {
                        #{generate_mongodb_example(model)}
                        "created_at": datetime.utcnow().isoformat(),
                        "updated_at": datetime.utcnow().isoformat()
                    }
                }

        class #{model_name.capitalize}(BaseModel):
            #{generate_mongodb_fields(model)}
            
            class Config:
                arbitrary_types_allowed = True
                json_encoders = {ObjectId: str}
                schema_extra = {
                    "example": {
                        #{generate_mongodb_example(model)}
                    }
                }

        class #{model_name.capitalize}Update(BaseModel):
            #{generate_mongodb_update_fields(model)}
            
            class Config:
                arbitrary_types_allowed = True
                json_encoders = {ObjectId: str}
                schema_extra = {
                    "example": {
                        #{generate_mongodb_example(model)}
                    }
                }
      PYTHON
      
      # Write model file
      File.write(model_file, model_content)
      
      log_info("Generated MongoDB model: #{model_name}")
    end
    
    def generate_mongodb_fields(model)
      return "" unless model[:attributes]
      
      model[:attributes].map do |attr|
        name = attr[:name]
        type = attr[:type]
        required = !attr[:nullable]
        
        "#{name}: #{mongodb_type_for(type)}#{required ? '' : ' = None'}"
      end.join("\n    ")
    end
    
    def generate_mongodb_update_fields(model)
      return "" unless model[:attributes]
      
      model[:attributes].map do |attr|
        name = attr[:name]
        type = attr[:type]
        
        "#{name}: Optional[#{mongodb_type_for(type)}] = None"
      end.join("\n    ")
    end
    
    def generate_mongodb_example(model)
      return "" unless model[:attributes]
      
      model[:attributes].map do |attr|
        name = attr[:name]
        type = attr[:type]
        
        example_value = case type.to_s.downcase
        when "string", "text"
          "\"example #{name}\""
        when "integer"
          "1"
        when "float", "decimal"
          "1.0"
        when "boolean"
          "True"
        when "datetime", "date"
          "datetime.utcnow().isoformat()"
        else
          "\"example\""
        end
        
        "\"#{name}\": #{example_value}"
      end.join(",\n                        ")
    end
    
    def mongodb_type_for(type)
      case type.to_s.downcase
      when "string", "text"
        "str"
      when "integer"
        "int"
      when "float", "decimal"
        "float"
      when "boolean"
        "bool"
      when "datetime", "date"
        "datetime"
      when "json"
        "dict"
      when "array"
        "List"
      else
        "str"
      end
    end
    
    def generate_pony_models
      log_info("Generating Pony ORM models")
      
      # Create __init__.py with all models
      init_content = "from pony.orm import *\nfrom datetime import datetime\nfrom app.db.database import db\n\n"
      
      # Generate each model
      @models.each do |model|
        init_content += generate_pony_model(model)
      end
      
      # Add database mapping
      init_content += "\n\ndb.generate_mapping(create_tables=True)\n"
      
      # Write init file
      File.write("#{@python_path}/app/models/__init__.py", init_content)
      
      log_info("Generated Pony ORM models")
    end
    
    def generate_pony_model(model)
      model_name = model[:name]
      
      log_info("Generating Pony ORM model: #{model_name}")
      
      # Generate model class
      model_content = <<~PYTHON
        class #{model_name.capitalize}(db.Entity):
            #{generate_pony_fields(model)}
            #{generate_pony_relationships(model)}
            created_at = Required(datetime, default=datetime.utcnow)
            updated_at = Required(datetime, default=datetime.utcnow)
      PYTHON
      
      log_info("Generated Pony ORM model: #{model_name}")
      
      model_content
    end
    
    def generate_pony_fields(model)
      return "" unless model[:attributes]
      
      model[:attributes].map do |attr|
        name = attr[:name]
        type = attr[:type]
        required = !attr[:nullable]
        unique = attr[:unique] || false
        
        "#{name} = #{required ? 'Required' : 'Optional'}(#{pony_type_for(type)}#{unique ? ', unique=True' : ''})"
      end.join("\n    ")
    end
    
    def generate_pony_relationships(model)
      return "" unless model[:associations]
      
      model[:associations].map do |assoc|
        kind = assoc[:kind]
        name = assoc[:name]
        
        case kind
        when "has_many"
          "#{name.downcase}s = Set(\"#{name.capitalize}\")"
        when "belongs_to"
          "#{name.downcase} = Required(\"#{name.capitalize}\")"
        when "has_one"
          "#{name.downcase} = Optional(\"#{name.capitalize}\")"
        else
          ""
        end
      end.join("\n    ")
    end
    
    def pony_type_for(type)
      case type.to_s.downcase
      when "string"
        "str"
      when "text"
        "str"
      when "integer"
        "int"
      when "float", "decimal"
        "float"
      when "boolean"
        "bool"
      when "datetime"
        "datetime"
      when "date"
        "date"
      when "time"
        "time"
      when "json"
        "Json"
      else
        "str"
      end
    end
    
    def generate_peewee_models
      log_info("Generating Peewee models")
      
      # Create __init__.py
      init_content = "# Import models here\n"
      
      # Generate each model
      @models.each do |model|
        model_name = model[:name]
        init_content += f"from app.models.{model_name.downcase} import {model_name.capitalize}\n"
        generate_peewee_model(model)
      end
      
      # Write init file
      File.write("#{@python_path}/app/models/__init__.py", init_content)
      
      log_info("Generated Peewee models")
    end
    
    def generate_peewee_model(model)
      model_name = model[:name]
      model_file = "#{@python_path}/app/models/#{model_name.downcase}.py"
      
      log_info("Generating Peewee model: #{model_name}")
      
      # Generate imports
      imports = <<~PYTHON
        import peewee
        from datetime import datetime
        from app.db.database import db
      PYTHON
      
      # Generate model class
      model_class = <<~PYTHON
        class #{model_name.capitalize}(peewee.Model):
            #{generate_peewee_fields(model)}
            #{generate_peewee_relationships(model)}
            created_at = peewee.DateTimeField(default=datetime.utcnow)
            updated_at = peewee.DateTimeField(default=datetime.utcnow)
            
            class Meta:
                database = db
                table_name = '#{model_name.downcase}s'
      PYTHON
      
      # Write model file
      File.write(model_file, imports + "\n" + model_class)
      
      log_info("Generated Peewee model: #{model_name}")
    end
    
    def generate_peewee_fields(model)
      return "" unless model[:attributes]
      
      model[:attributes].map do |attr|
        name = attr[:name]
        type = attr[:type]
        nullable = attr[:nullable] || false
        unique = attr[:unique] || false
        
        "#{name} = #{peewee_type_for(type)}(null=#{nullable}, unique=#{unique})"
      end.join("\n    ")
    end
    
    def generate_peewee_relationships(model)
      return "" unless model[:associations]
      
      model[:associations].map do |assoc|
        kind = assoc[:kind]
        name = assoc[:name]
        
        case kind
        when "belongs_to"
          "#{name}_id = peewee.ForeignKeyField(#{name.capitalize}, backref='#{model[:name].downcase}s')"
        else
          ""
        end
      end.join("\n    ")
    end
    
    def peewee_type_for(type)
      case type.to_s.downcase
      when "string"
        "peewee.CharField"
      when "text"
        "peewee.TextField"
      when "integer"
        "peewee.IntegerField"
      when "float", "decimal"
        "peewee.FloatField"
      when "boolean"
        "peewee.BooleanField"
      when "datetime"
        "peewee.DateTimeField"
      when "date"
        "peewee.DateField"
      when "time"
        "peewee.TimeField"
      when "json"
        "peewee.JSONField"
      else
        "peewee.CharField"
      end
    end
    
    def generate_django_models
      log_info("Generating Django models")
      
      # Create __init__.py
      File.write("#{@python_path}/api/models/__init__.py", "# Import models here\n")
      
      # Generate each model
      @models.each do |model|
        generate_django_model(model)
      end
    end
    
    def generate_django_model(model)
      model_name = model[:name]
      model_file = "#{@python_path}/api/models/#{model_name.downcase}.py"
      
      log_info("Generating Django model: #{model_name}")
      
      # Generate model class
      model_content = <<~PYTHON
        from django.db import models
        from django.utils import timezone

        class #{model_name.capitalize}(models.Model):
            #{generate_django_fields(model)}
            #{generate_django_relationships(model)}
            created_at = models.DateTimeField(default=timezone.now)
            updated_at = models.DateTimeField(auto_now=True)
            
            def __str__(self):
                return f"#{model_name.capitalize} {self.id}"
            
            class Meta:
                ordering = ['-created_at']
      PYTHON
      
      # Write model file
      File.write(model_file, model_content)
      
      log_info("Generated Django model: #{model_name}")
    end
    
    def generate_django_fields(model)
      return "" unless model[:attributes]
      
      model[:attributes].map do |attr|
        name = attr[:name]
        type = attr[:type]
        nullable = attr[:nullable] || false
        unique = attr[:unique] || false
        
        "#{name} = #{django_type_for(type)}(null=#{nullable}, blank=#{nullable}, unique=#{unique})"
      end.join("\n    ")
    end
    
    def generate_django_relationships(model)
      return "" unless model[:associations]
      
      model[:associations].map do |assoc|
        kind = assoc[:kind]
        name = assoc[:name]
        
        case kind
        when "has_many"
          ""  # Django handles this from the other side
        when "belongs_to"
          "#{name} = models.ForeignKey('#{name.capitalize}', on_delete=models.CASCADE, related_name='#{model[:name].downcase}s')"
        when "has_one"
          "#{name} = models.OneToOneField('#{name.capitalize}', on_delete=models.CASCADE, related_name='#{model[:name].downcase}')"
        else
          ""
        end
      end.join("\n    ")
    end
    
    def django_type_for(type)
      case type.to_s.downcase
      when "string"
        "models.CharField(max_length=255)"
      when "text"
        "models.TextField()"
      when "integer"
        "models.IntegerField()"
      when "float", "decimal"
        "models.FloatField()"
      when "boolean"
        "models.BooleanField()"
      when "datetime"
        "models.DateTimeField()"
      when "date"
        "models.DateField()"
      when "time"
        "models.TimeField()"
      when "json"
        "models.JSONField()"
      else
        "models.CharField(max_length=255)"
      end
    end
    
    def generate_schemas
      log_info("Generating schemas")
      
      # Skip for Django as it uses serializers instead
      return if @database_type.to_s.downcase == "django-orm"
      
      # Create __init__.py
      File.write("#{@python_path}/app/schemas/__init__.py", "# Import schemas here\n")
      
      # Generate each schema
      @models.each do |model|
        generate_schema(model)
      end
      
      log_info("Schemas generated")
    end
    
    def generate_schema(model)
      model_name = model[:name]
      schema_file = "#{@python_path}/app/schemas/#{model_name.downcase}.py"
      
      log_info("Generating schema: #{model_name}")
      
      # Generate schema class
      schema_content = <<~PYTHON
        from typing import Optional, List
        from datetime import datetime
        from pydantic import BaseModel, Field

        # Schema for creating a new #{model_name.capitalize}
        class #{model_name.capitalize}Create(BaseModel):
            #{generate_schema_fields(model, false)}
            
            class Config:
                schema_extra = {
                    "example": {
                        #{generate_schema_example(model)}
                    }
                }

        # Schema for updating a #{model_name.capitalize}
        class #{model_name.capitalize}Update(BaseModel):
            #{generate_schema_fields(model, true)}
            
            class Config:
                schema_extra = {
                    "example": {
                        #{generate_schema_example(model)}
                    }
                }

        # Schema for returning a #{model_name.capitalize}
        class #{model_name.capitalize}(BaseModel):
            id: int
            #{generate_schema_fields(model, false)}
            created_at: datetime
            updated_at: datetime
            
            class Config:
                orm_mode = True
                schema_extra = {
                    "example": {
                        "id": 1,
                        #{generate_schema_example(model)},
                        "created_at": datetime.utcnow().isoformat(),
                        "updated_at": datetime.utcnow().isoformat()
                    }
                }

        # Schema for returning multiple #{model_name.capitalize}s
        class #{model_name.capitalize}List(BaseModel):
            items: List[#{model_name.capitalize}]
            total: int
            page: int
            size: int
            pages: int
      PYTHON
      
      # Write schema file
      File.write(schema_file, schema_content)
      
      log_info("Generated schema: #{model_name}")
    end
    
    def generate_schema_fields(model, optional)
      return "" unless model[:attributes]
      
      model[:attributes].map do |attr|
        name = attr[:name]
        type = attr[:type]
        
        if optional
          "#{name}: Optional[#{schema_type_for(type)}] = None"
        else
          "#{name}: #{schema_type_for(type)}"
        end
      end.join("\n    ")
    end
    
    def generate_schema_example(model)
      return "" unless model[:attributes]
      
      model[:attributes].map do |attr|
        name = attr[:name]
        type = attr[:type]
        
        example_value = case type.to_s.downcase
        when "string", "text"
          "\"example #{name}\""
        when "integer"
          "1"
        when "float", "decimal"
          "1.0"
        when "boolean"
          "True"
        when "datetime", "date"
          "\"2023-01-01T00:00:00\""
        else
          "\"example\""
        end
        
        "\"#{name}\": #{example_value}"
      end.join(",\n                        ")
    end
    
    def schema_type_for(type)
      case type.to_s.downcase
      when "string", "text"
        "str"
      when "integer"
        "int"
      when "float", "decimal"
        "float"
      when "boolean"
        "bool"
      when "datetime", "date"
        "datetime"
      when "json"
        "dict"
      when "array"
        "List"
      else
        "str"
      end
    end
  end
end 