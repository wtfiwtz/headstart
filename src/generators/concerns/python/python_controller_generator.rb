module Tenant
  module PythonControllerGenerator
    def generate_controllers
      log_info("Generating controllers for #{@models.length} models")
      
      # Generate controllers based on framework and database type
      case @framework_type.to_s.downcase
      when "fastapi"
        generate_fastapi_controllers
      when "flask"
        generate_flask_controllers
      when "django"
        generate_django_controllers
      end
      
      log_info("Controllers generated")
    end
    
    def generate_fastapi_controllers
      log_info("Generating FastAPI controllers")
      
      # Create __init__.py
      File.write("#{@python_path}/app/api/endpoints/__init__.py", "# Import endpoints here\n")
      
      # Generate each controller
      @models.each do |model|
        generate_fastapi_controller(model)
      end
    end
    
    def generate_fastapi_controller(model)
      model_name = model[:name]
      controller_file = "#{@python_path}/app/api/endpoints/#{model_name.downcase}.py"
      
      log_info("Generating FastAPI controller: #{model_name}")
      
      # Generate controller based on database type
      controller_content = case @database_type.to_s.downcase
      when "sqlalchemy"
        generate_fastapi_sqlalchemy_controller(model)
      when "mongodb"
        generate_fastapi_mongodb_controller(model)
      when "pony"
        generate_fastapi_pony_controller(model)
      when "peewee"
        generate_fastapi_peewee_controller(model)
      else
        generate_fastapi_sqlalchemy_controller(model)
      end
      
      # Write controller file
      File.write(controller_file, controller_content)
      
      log_info("Generated FastAPI controller: #{model_name}")
    end
    
    def generate_fastapi_sqlalchemy_controller(model)
      model_name = model[:name]
      model_var = model_name.downcase
      
      # Generate controller content
      <<~PYTHON
        from typing import List, Optional
        from fastapi import APIRouter, Depends, HTTPException, Query, Path
        from sqlalchemy.orm import Session
        from app.db.session import get_db
        from app.models.#{model_var} import #{model_name.capitalize}
        from app.schemas.#{model_var} import #{model_name.capitalize} as #{model_name.capitalize}Schema
        from app.schemas.#{model_var} import #{model_name.capitalize}Create, #{model_name.capitalize}Update, #{model_name.capitalize}List

        router = APIRouter()

        @router.get("/", response_model=#{model_name.capitalize}List)
        def get_#{model_var}s(
            db: Session = Depends(get_db),
            skip: int = Query(0, ge=0),
            limit: int = Query(100, ge=1, le=100),
            #{model[:attributes] ? model[:attributes].map { |attr| "#{attr[:name]}: Optional[#{schema_type_for(attr[:type])}] = Query(None)" }.join(",\n    ") : ""}
        ):
            """
            Get all #{model_var}s with optional filtering
            """
            # Base query
            query = db.query(#{model_name.capitalize})
            
            # Apply filters if provided
            #{model[:attributes] ? model[:attributes].map { |attr| "if #{attr[:name]} is not None:\n        query = query.filter(#{model_name.capitalize}.#{attr[:name]} == #{attr[:name]})" }.join("\n    ") : ""}
            
            # Get total count for pagination
            total = query.count()
            
            # Apply pagination
            #{model_var}s = query.offset(skip).limit(limit).all()
            
            # Calculate pagination values
            page = skip // limit + 1 if limit > 0 else 1
            pages = (total + limit - 1) // limit if limit > 0 else 1
            
            return #{model_name.capitalize}List(
                items=#{model_var}s,
                total=total,
                page=page,
                size=limit,
                pages=pages
            )

        @router.post("/", response_model=#{model_name.capitalize}Schema)
        def create_#{model_var}(
            #{model_var}: #{model_name.capitalize}Create,
            db: Session = Depends(get_db)
        ):
            """
            Create a new #{model_var}
            """
            db_#{model_var} = #{model_name.capitalize}(**#{model_var}.dict())
            db.add(db_#{model_var})
            db.commit()
            db.refresh(db_#{model_var})
            return db_#{model_var}

        @router.get("/{#{model_var}_id}", response_model=#{model_name.capitalize}Schema)
        def get_#{model_var}(
            #{model_var}_id: int = Path(..., gt=0),
            db: Session = Depends(get_db)
        ):
            """
            Get a specific #{model_var} by ID
            """
            db_#{model_var} = db.query(#{model_name.capitalize}).filter(#{model_name.capitalize}.id == #{model_var}_id).first()
            if db_#{model_var} is None:
                raise HTTPException(status_code=404, detail="#{model_name.capitalize} not found")
            return db_#{model_var}

        @router.put("/{#{model_var}_id}", response_model=#{model_name.capitalize}Schema)
        def update_#{model_var}(
            #{model_var}_id: int = Path(..., gt=0),
            #{model_var}: #{model_name.capitalize}Update = None,
            db: Session = Depends(get_db)
        ):
            """
            Update a #{model_var}
            """
            db_#{model_var} = db.query(#{model_name.capitalize}).filter(#{model_name.capitalize}.id == #{model_var}_id).first()
            if db_#{model_var} is None:
                raise HTTPException(status_code=404, detail="#{model_name.capitalize} not found")
                
            # Update model with provided values, skipping None values
            update_data = #{model_var}.dict(exclude_unset=True)
            for key, value in update_data.items():
                if value is not None:
                    setattr(db_#{model_var}, key, value)
                    
            db.commit()
            db.refresh(db_#{model_var})
            return db_#{model_var}

        @router.delete("/{#{model_var}_id}", response_model=dict)
        def delete_#{model_var}(
            #{model_var}_id: int = Path(..., gt=0),
            db: Session = Depends(get_db)
        ):
            """
            Delete a #{model_var}
            """
            db_#{model_var} = db.query(#{model_name.capitalize}).filter(#{model_name.capitalize}.id == #{model_var}_id).first()
            if db_#{model_var} is None:
                raise HTTPException(status_code=404, detail="#{model_name.capitalize} not found")
                
            db.delete(db_#{model_var})
            db.commit()
            
            return {"status": "success", "message": "#{model_name.capitalize} deleted successfully"}
      PYTHON
    end
    
    def generate_fastapi_mongodb_controller(model)
      model_name = model[:name]
      model_var = model_name.downcase
      
      # Generate controller content
      <<~PYTHON
        from typing import List, Optional
        from fastapi import APIRouter, HTTPException, Query, Path, Body, Depends
        from app.db.database import db
        from app.models.#{model_var} import #{model_name.capitalize}, #{model_name.capitalize}Update, #{model_name.capitalize}Model
        from bson import ObjectId
        from datetime import datetime

        router = APIRouter()

        @router.get("/", response_model=List[#{model_name.capitalize}Model])
        async def get_#{model_var}s(
            skip: int = Query(0, ge=0),
            limit: int = Query(100, ge=1, le=100),
            #{model[:attributes] ? model[:attributes].map { |attr| "#{attr[:name]}: Optional[#{schema_type_for(attr[:type])}] = Query(None)" }.join(",\n    ") : ""}
        ):
            """
            Get all #{model_var}s with optional filtering
            """
            # Base query
            query = {}
            
            # Apply filters if provided
            #{model[:attributes] ? model[:attributes].map { |attr| "if #{attr[:name]} is not None:\n        query[\"#{attr[:name]}\"] = #{attr[:name]}" }.join("\n    ") : ""}
            
            # Get total count for pagination
            total = await db.#{model_var}s.count_documents(query)
            
            # Apply pagination
            cursor = db.#{model_var}s.find(query).skip(skip).limit(limit)
            #{model_var}s = await cursor.to_list(length=limit)
            
            return #{model_var}s

        @router.post("/", response_model=#{model_name.capitalize}Model)
        async def create_#{model_var}(
            #{model_var}: #{model_name.capitalize} = Body(...)
        ):
            """
            Create a new #{model_var}
            """
            #{model_var}_dict = #{model_var}.dict()
            #{model_var}_dict["created_at"] = datetime.utcnow()
            #{model_var}_dict["updated_at"] = datetime.utcnow()
            
            result = await db.#{model_var}s.insert_one(#{model_var}_dict)
            
            created_#{model_var} = await db.#{model_var}s.find_one({"_id": result.inserted_id})
            
            return created_#{model_var}

        @router.get("/{#{model_var}_id}", response_model=#{model_name.capitalize}Model)
        async def get_#{model_var}(
            #{model_var}_id: str = Path(...)
        ):
            """
            Get a specific #{model_var} by ID
            """
            if not ObjectId.is_valid(#{model_var}_id):
                raise HTTPException(status_code=400, detail="Invalid ID format")
                
            #{model_var} = await db.#{model_var}s.find_one({"_id": ObjectId(#{model_var}_id)})
            
            if #{model_var} is None:
                raise HTTPException(status_code=404, detail="#{model_name.capitalize} not found")
                
            return #{model_var}

        @router.put("/{#{model_var}_id}", response_model=#{model_name.capitalize}Model)
        async def update_#{model_var}(
            #{model_var}_id: str = Path(...),
            #{model_var}: #{model_name.capitalize}Update = Body(...)
        ):
            """
            Update a #{model_var}
            """
            if not ObjectId.is_valid(#{model_var}_id):
                raise HTTPException(status_code=400, detail="Invalid ID format")
                
            # Check if #{model_var} exists
            existing_#{model_var} = await db.#{model_var}s.find_one({"_id": ObjectId(#{model_var}_id)})
            if existing_#{model_var} is None:
                raise HTTPException(status_code=404, detail="#{model_name.capitalize} not found")
                
            # Update model with provided values, skipping None values
            update_data = #{model_var}.dict(exclude_unset=True, exclude_none=True)
            
            if update_data:
                update_data["updated_at"] = datetime.utcnow()
                
                await db.#{model_var}s.update_one(
                    {"_id": ObjectId(#{model_var}_id)},
                    {"$set": update_data}
                )
                
            updated_#{model_var} = await db.#{model_var}s.find_one({"_id": ObjectId(#{model_var}_id)})
            
            return updated_#{model_var}

        @router.delete("/{#{model_var}_id}", response_model=dict)
        async def delete_#{model_var}(
            #{model_var}_id: str = Path(...)
        ):
            """
            Delete a #{model_var}
            """
            if not ObjectId.is_valid(#{model_var}_id):
                raise HTTPException(status_code=400, detail="Invalid ID format")
                
            # Check if #{model_var} exists
            existing_#{model_var} = await db.#{model_var}s.find_one({"_id": ObjectId(#{model_var}_id)})
            if existing_#{model_var} is None:
                raise HTTPException(status_code=404, detail="#{model_name.capitalize} not found")
                
            await db.#{model_var}s.delete_one({"_id": ObjectId(#{model_var}_id)})
            
            return {"status": "success", "message": "#{model_name.capitalize} deleted successfully"}
      PYTHON
    end
    
    def generate_fastapi_pony_controller(model)
      model_name = model[:name]
      model_var = model_name.downcase
      
      # Generate controller content
      <<~PYTHON
        from typing import List, Optional
        from fastapi import APIRouter, HTTPException, Query, Path, Body, Depends
        from pony.orm import db_session, select, count
        from app.models import #{model_name.capitalize}
        from app.schemas.#{model_var} import #{model_name.capitalize} as #{model_name.capitalize}Schema
        from app.schemas.#{model_var} import #{model_name.capitalize}Create, #{model_name.capitalize}Update, #{model_name.capitalize}List

        router = APIRouter()

        @router.get("/", response_model=#{model_name.capitalize}List)
        @db_session
        def get_#{model_var}s(
            skip: int = Query(0, ge=0),
            limit: int = Query(100, ge=1, le=100),
            #{model[:attributes] ? model[:attributes].map { |attr| "#{attr[:name]}: Optional[#{schema_type_for(attr[:type])}] = Query(None)" }.join(",\n    ") : ""}
        ):
            """
            Get all #{model_var}s with optional filtering
            """
            # Base query
            query = select(m for m in #{model_name.capitalize})
            
            # Apply filters if provided
            #{model[:attributes] ? model[:attributes].map { |attr| "if #{attr[:name]} is not None:\n        query = query.filter(lambda m: m.#{attr[:name]} == #{attr[:name]})" }.join("\n    ") : ""}
            
            # Get total count for pagination
            total = count(query)
            
            # Apply pagination
            #{model_var}s = query.offset(skip).limit(limit)[:]
            
            # Calculate pagination values
            page = skip // limit + 1 if limit > 0 else 1
            pages = (total + limit - 1) // limit if limit > 0 else 1
            
            return #{model_name.capitalize}List(
                items=#{model_var}s,
                total=total,
                page=page,
                size=limit,
                pages=pages
            )

        @router.post("/", response_model=#{model_name.capitalize}Schema)
        @db_session
        def create_#{model_var}(
            #{model_var}: #{model_name.capitalize}Create = Body(...)
        ):
            """
            Create a new #{model_var}
            """
            db_#{model_var} = #{model_name.capitalize}(**#{model_var}.dict())
            return db_#{model_var}

        @router.get("/{#{model_var}_id}", response_model=#{model_name.capitalize}Schema)
        @db_session
        def get_#{model_var}(
            #{model_var}_id: int = Path(..., gt=0)
        ):
            """
            Get a specific #{model_var} by ID
            """
            db_#{model_var} = #{model_name.capitalize}.get(id=#{model_var}_id)
            if db_#{model_var} is None:
                raise HTTPException(status_code=404, detail="#{model_name.capitalize} not found")
            return db_#{model_var}

        @router.put("/{#{model_var}_id}", response_model=#{model_name.capitalize}Schema)
        @db_session
        def update_#{model_var}(
            #{model_var}_id: int = Path(..., gt=0),
            #{model_var}: #{model_name.capitalize}Update = Body(...)
        ):
            """
            Update a #{model_var}
            """
            db_#{model_var} = #{model_name.capitalize}.get(id=#{model_var}_id)
            if db_#{model_var} is None:
                raise HTTPException(status_code=404, detail="#{model_name.capitalize} not found")
                
            # Update model with provided values, skipping None values
            update_data = #{model_var}.dict(exclude_unset=True)
            for key, value in update_data.items():
                if value is not None:
                    setattr(db_#{model_var}, key, value)
                    
            return db_#{model_var}

        @router.delete("/{#{model_var}_id}", response_model=dict)
        @db_session
        def delete_#{model_var}(
            #{model_var}_id: int = Path(..., gt=0)
        ):
            """
            Delete a #{model_var}
            """
            db_#{model_var} = #{model_name.capitalize}.get(id=#{model_var}_id)
            if db_#{model_var} is None:
                raise HTTPException(status_code=404, detail="#{model_name.capitalize} not found")
                
            db_#{model_var}.delete()
            
            return {"status": "success", "message": "#{model_name.capitalize} deleted successfully"}
      PYTHON
    end
    
    def generate_fastapi_peewee_controller(model)
      model_name = model[:name]
      model_var = model_name.downcase
      
      # Generate controller content
      <<~PYTHON
        from typing import List, Optional
        from fastapi import APIRouter, HTTPException, Query, Path, Body, Depends
        from app.models.#{model_var} import #{model_name.capitalize}
        from app.schemas.#{model_var} import #{model_name.capitalize} as #{model_name.capitalize}Schema
        from app.schemas.#{model_var} import #{model_name.capitalize}Create, #{model_name.capitalize}Update, #{model_name.capitalize}List
        from peewee import DoesNotExist

        router = APIRouter()

        @router.get("/", response_model=#{model_name.capitalize}List)
        def get_#{model_var}s(
            skip: int = Query(0, ge=0),
            limit: int = Query(100, ge=1, le=100),
            #{model[:attributes] ? model[:attributes].map { |attr| "#{attr[:name]}: Optional[#{schema_type_for(attr[:type])}] = Query(None)" }.join(",\n    ") : ""}
        ):
            """
            Get all #{model_var}s with optional filtering
            """
            # Base query
            query = #{model_name.capitalize}.select()
            
            # Apply filters if provided
            #{model[:attributes] ? model[:attributes].map { |attr| "if #{attr[:name]} is not None:\n        query = query.where(#{model_name.capitalize}.#{attr[:name]} == #{attr[:name]})" }.join("\n    ") : ""}
            
            # Get total count for pagination
            total = query.count()
            
            # Apply pagination
            #{model_var}s = list(query.offset(skip).limit(limit))
            
            # Calculate pagination values
            page = skip // limit + 1 if limit > 0 else 1
            pages = (total + limit - 1) // limit if limit > 0 else 1
            
            return #{model_name.capitalize}List(
                items=#{model_var}s,
                total=total,
                page=page,
                size=limit,
                pages=pages
            )

        @router.post("/", response_model=#{model_name.capitalize}Schema)
        def create_#{model_var}(
            #{model_var}: #{model_name.capitalize}Create = Body(...)
        ):
            """
            Create a new #{model_var}
            """
            db_#{model_var} = #{model_name.capitalize}.create(**#{model_var}.dict())
            return db_#{model_var}

        @router.get("/{#{model_var}_id}", response_model=#{model_name.capitalize}Schema)
        def get_#{model_var}(
            #{model_var}_id: int = Path(..., gt=0)
        ):
            """
            Get a specific #{model_var} by ID
            """
            try:
                db_#{model_var} = #{model_name.capitalize}.get_by_id(#{model_var}_id)
                return db_#{model_var}
            except DoesNotExist:
                raise HTTPException(status_code=404, detail="#{model_name.capitalize} not found")

        @router.put("/{#{model_var}_id}", response_model=#{model_name.capitalize}Schema)
        def update_#{model_var}(
            #{model_var}_id: int = Path(..., gt=0),
            #{model_var}: #{model_name.capitalize}Update = Body(...)
        ):
            """
            Update a #{model_var}
            """
            try:
                db_#{model_var} = #{model_name.capitalize}.get_by_id(#{model_var}_id)
                
                # Update model with provided values, skipping None values
                update_data = #{model_var}.dict(exclude_unset=True)
                for key, value in update_data.items():
                    if value is not None:
                        setattr(db_#{model_var}, key, value)
                        
                db_#{model_var}.save()
                return db_#{model_var}
            except DoesNotExist:
                raise HTTPException(status_code=404, detail="#{model_name.capitalize} not found")

        @router.delete("/{#{model_var}_id}", response_model=dict)
        def delete_#{model_var}(
            #{model_var}_id: int = Path(..., gt=0)
        ):
            """
            Delete a #{model_var}
            """
            try:
                db_#{model_var} = #{model_name.capitalize}.get_by_id(#{model_var}_id)
                db_#{model_var}.delete_instance()
                return {"status": "success", "message": "#{model_name.capitalize} deleted successfully"}
            except DoesNotExist:
                raise HTTPException(status_code=404, detail="#{model_name.capitalize} not found")
      PYTHON
    end
    
    def generate_flask_controllers
      log_info("Generating Flask controllers")
      
      # Implementation for Flask controllers
      # ...
    end
    
    def generate_django_controllers
      log_info("Generating Django controllers")
      
      # Implementation for Django controllers
      # ...
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