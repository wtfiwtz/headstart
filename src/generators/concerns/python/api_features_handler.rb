module Tenant
  module PythonApiFeaturesHandler
    def generate_api_features
      log_info("Generating API features")
      
      # Skip if no API features are enabled
      unless @api_features && (@api_features[:pagination] || @api_features[:sorting] || @api_features[:filtering])
        log_info("No API features enabled, skipping")
        return
      end
      
      # Generate API features based on framework
      case @framework_type.to_s.downcase
      when "fastapi"
        generate_fastapi_api_features
      when "flask"
        generate_flask_api_features
      when "django"
        generate_django_api_features
      end
      
      log_info("API features generated")
    end
    
    def generate_fastapi_api_features
      log_info("Generating FastAPI API features")
      
      # Create utils directory if it doesn't exist
      FileUtils.mkdir_p("#{@python_path}/app/utils")
      
      # Create __init__.py
      File.write("#{@python_path}/app/utils/__init__.py", "")
      
      # Generate pagination
      generate_fastapi_pagination if @api_features[:pagination]
      
      # Generate sorting
      generate_fastapi_sorting if @api_features[:sorting]
      
      # Generate filtering
      generate_fastapi_filtering if @api_features[:filtering]
      
      # Update controllers with API features
      update_fastapi_controllers_with_api_features
    end
    
    def generate_fastapi_pagination
      log_info("Generating FastAPI pagination")
      
      # Create pagination.py
      pagination_content = <<~PYTHON
        from typing import Generic, TypeVar, List, Optional, Dict, Any
        from fastapi import Query, Depends
        from pydantic import BaseModel
        from pydantic.generics import GenericModel

        T = TypeVar('T')

        class PageParams:
            def __init__(
                self,
                page: int = Query(1, ge=1, description="Page number"),
                size: int = Query(10, ge=1, le=100, description="Items per page")
            ):
                self.page = page
                self.size = size
                self.offset = (page - 1) * size

        class Page(GenericModel, Generic[T]):
            items: List[T]
            total: int
            page: int
            size: int
            pages: int

            @classmethod
            def create(cls, items: List[T], total: int, params: PageParams) -> "Page[T]":
                pages = (total + params.size - 1) // params.size if params.size > 0 else 1
                return cls(
                    items=items,
                    total=total,
                    page=params.page,
                    size=params.size,
                    pages=pages
                )

        def paginate(query, params: PageParams):
            total = query.count()
            items = query.offset(params.offset).limit(params.size).all()
            return Page.create(items, total, params)

        async def paginate_mongodb(collection, query: Dict[str, Any], params: PageParams):
            total = await collection.count_documents(query)
            cursor = collection.find(query).skip(params.offset).limit(params.size)
            items = await cursor.to_list(length=params.size)
            return Page.create(items, total, params)
      PYTHON
      
      File.write("#{@python_path}/app/utils/pagination.py", pagination_content)
      
      log_info("Generated FastAPI pagination")
    end
    
    def generate_fastapi_sorting
      log_info("Generating FastAPI sorting")
      
      # Create sorting.py
      sorting_content = <<~PYTHON
        from typing import List, Optional, Dict, Any, Callable, Type, Union
        from fastapi import Query
        from sqlalchemy.orm import Query as SQLAlchemyQuery
        from pydantic import BaseModel

        class SortParams:
            def __init__(
                self,
                sort: Optional[str] = Query(None, description="Sort fields (e.g. name:asc,created_at:desc)")
            ):
                self.sort_fields = []
                if sort:
                    for field in sort.split(','):
                        if ':' in field:
                            field_name, direction = field.split(':')
                            direction = direction.lower()
                            if direction not in ['asc', 'desc']:
                                direction = 'asc'
                        else:
                            field_name = field
                            direction = 'asc'
                        
                        self.sort_fields.append((field_name, direction))

        def apply_sorting(query: SQLAlchemyQuery, model: Type[BaseModel], params: SortParams) -> SQLAlchemyQuery:
            """
            Apply sorting to a SQLAlchemy query
            """
            if not params.sort_fields:
                return query
                
            for field_name, direction in params.sort_fields:
                if hasattr(model, field_name):
                    field = getattr(model, field_name)
                    if direction == 'desc':
                        query = query.order_by(field.desc())
                    else:
                        query = query.order_by(field.asc())
                        
            return query

        def get_mongodb_sort(params: SortParams) -> Dict[str, int]:
            """
            Get MongoDB sort dictionary
            """
            sort_dict = {}
            for field_name, direction in params.sort_fields:
                sort_dict[field_name] = -1 if direction == 'desc' else 1
                
            return sort_dict
      PYTHON
      
      File.write("#{@python_path}/app/utils/sorting.py", sorting_content)
      
      log_info("Generated FastAPI sorting")
    end
    
    def generate_fastapi_filtering
      log_info("Generating FastAPI filtering")
      
      # Create filtering.py
      filtering_content = <<~PYTHON
        from typing import Dict, Any, List, Optional, Type, Union
        from fastapi import Query
        from sqlalchemy.orm import Query as SQLAlchemyQuery
        from sqlalchemy import or_, and_
        from pydantic import BaseModel
        import re

        class FilterParams:
            def __init__(
                self,
                filter: Optional[str] = Query(None, description="Filter fields (e.g. name:John,age:gt:18)")
            ):
                self.filter_conditions = []
                if filter:
                    for condition in filter.split(','):
                        parts = condition.split(':')
                        
                        if len(parts) == 2:
                            # Simple equality filter
                            field_name, value = parts
                            self.filter_conditions.append((field_name, 'eq', value))
                        elif len(parts) == 3:
                            # Operator filter
                            field_name, operator, value = parts
                            self.filter_conditions.append((field_name, operator, value))

        def apply_filtering(query: SQLAlchemyQuery, model: Type[BaseModel], params: FilterParams) -> SQLAlchemyQuery:
            """
            Apply filtering to a SQLAlchemy query
            """
            if not params.filter_conditions:
                return query
                
            for field_name, operator, value in params.filter_conditions:
                if hasattr(model, field_name):
                    field = getattr(model, field_name)
                    
                    if operator == 'eq' or operator == '':
                        query = query.filter(field == value)
                    elif operator == 'ne':
                        query = query.filter(field != value)
                    elif operator == 'gt':
                        query = query.filter(field > value)
                    elif operator == 'lt':
                        query = query.filter(field < value)
                    elif operator == 'gte':
                        query = query.filter(field >= value)
                    elif operator == 'lte':
                        query = query.filter(field <= value)
                    elif operator == 'like':
                        query = query.filter(field.like(f'%{value}%'))
                    elif operator == 'in':
                        values = value.split('|')
                        query = query.filter(field.in_(values))
                        
            return query

        def get_mongodb_filter(params: FilterParams) -> Dict[str, Any]:
            """
            Get MongoDB filter dictionary
            """
            filter_dict = {}
            for field_name, operator, value in params.filter_conditions:
                if operator == 'eq' or operator == '':
                    filter_dict[field_name] = value
                elif operator == 'ne':
                    filter_dict[field_name] = {'$ne': value}
                elif operator == 'gt':
                    filter_dict[field_name] = {'$gt': value}
                elif operator == 'lt':
                    filter_dict[field_name] = {'$lt': value}
                elif operator == 'gte':
                    filter_dict[field_name] = {'$gte': value}
                elif operator == 'lte':
                    filter_dict[field_name] = {'$lte': value}
                elif operator == 'regex':
                    filter_dict[field_name] = {'$regex': value, '$options': 'i'}
                elif operator == 'in':
                    values = value.split('|')
                    filter_dict[field_name] = {'$in': values}
                    
            return filter_dict
      PYTHON
      
      File.write("#{@python_path}/app/utils/filtering.py", filtering_content)
      
      log_info("Generated FastAPI filtering")
    end
    
    def update_fastapi_controllers_with_api_features
      log_info("Updating FastAPI controllers with API features")
      
      # Skip if no models
      return if @models.empty?
      
      # For each model, update the controller
      @models.each do |model|
        model_name = model[:name]
        model_var = model_name.downcase
        controller_file = "#{@python_path}/app/api/endpoints/#{model_var}.py"
        
        # Skip if controller doesn't exist
        next unless File.exist?(controller_file)
        
        # Read existing controller
        controller_content = File.read(controller_file)
        
        # Update imports
        imports = []
        imports << "from app.utils.pagination import PageParams, Page" if @api_features[:pagination]
        imports << "from app.utils.sorting import SortParams, apply_sorting, get_mongodb_sort" if @api_features[:sorting]
        imports << "from app.utils.filtering import FilterParams, apply_filtering, get_mongodb_filter" if @api_features[:filtering]
        
        # Add imports to controller
        if imports.any?
          controller_content.gsub!(/from fastapi import (.+)/, "from fastapi import \\1, #{imports.any? ? 'Depends' : ''}")
          controller_content.gsub!(/from typing import (.+)/, "from typing import \\1")
          controller_content.gsub!(/import (.+)/, "import \\1\n#{imports.join("\n")}")
        end
        
        # Update controller based on database type
        case @database_type.to_s.downcase
        when "sqlalchemy"
          update_fastapi_sqlalchemy_controller(controller_content, model)
        when "mongodb"
          update_fastapi_mongodb_controller(controller_content, model)
        when "pony"
          update_fastapi_pony_controller(controller_content, model)
        when "peewee"
          update_fastapi_peewee_controller(controller_content, model)
        end
        
        # Write updated controller
        File.write(controller_file, controller_content)
      end
      
      log_info("Updated FastAPI controllers with API features")
    end
    
    def update_fastapi_sqlalchemy_controller(controller_content, model)
      model_name = model[:name]
      model_var = model_name.downcase
      
      # Update get_#{model_var}s method
      if @api_features[:pagination]
        controller_content.gsub!(
          /def get_#{model_var}s\(\s*db: Session = Depends\(get_db\),\s*skip: int = Query\(0, ge=0\),\s*limit: int = Query\(100, ge=1, le=100\),/,
          "def get_#{model_var}s(\n    db: Session = Depends(get_db),\n    page_params: PageParams = Depends(),"
        )
        
        controller_content.gsub!(
          /# Apply pagination\s*#{model_var}s = query\.offset\(skip\)\.limit\(limit\)\.all\(\)\s*\n\s*# Calculate pagination values\s*page = skip \/\/ limit \+ 1 if limit > 0 else 1\s*\n\s*pages = \(total \+ limit - 1\) \/\/ limit if limit > 0 else 1\s*\n\s*return #{model_name.capitalize}List\(\s*items=#{model_var}s,\s*total=total,\s*page=page,\s*size=limit,\s*pages=pages\s*\)/,
          "# Apply pagination\n    return Page.create(\n        items=query.offset(page_params.offset).limit(page_params.size).all(),\n        total=total,\n        params=page_params\n    )"
        )
      end
      
      if @api_features[:sorting]
        controller_content.gsub!(
          /def get_#{model_var}s\(\s*db: Session = Depends\(get_db\),(\s*page_params: PageParams = Depends\(\),)?/,
          "def get_#{model_var}s(\n    db: Session = Depends(get_db),\\1\n    sort_params: SortParams = Depends(),"
        )
        
        controller_content.gsub!(
          /# Apply filters if provided(\s*.*\n)+?\s*# Get total count for pagination/,
          "# Apply filters if provided\\1\n    \n    # Apply sorting\n    query = apply_sorting(query, #{model_name.capitalize}, sort_params)\n    \n    # Get total count for pagination"
        )
      end
      
      if @api_features[:filtering]
        controller_content.gsub!(
          /def get_#{model_var}s\(\s*db: Session = Depends\(get_db\),(\s*page_params: PageParams = Depends\(\),)?(\s*sort_params: SortParams = Depends\(\),)?/,
          "def get_#{model_var}s(\n    db: Session = Depends(get_db),\\1\\2\n    filter_params: FilterParams = Depends(),"
        )
        
        controller_content.gsub!(
          /# Apply filters if provided(\s*.*\n)+?\s*(# Apply sorting|# Get total count for pagination)/,
          "# Apply filters if provided\\1\n    \n    # Apply advanced filtering\n    query = apply_filtering(query, #{model_name.capitalize}, filter_params)\n    \n    \\2"
        )
      end
    end
    
    def update_fastapi_mongodb_controller(controller_content, model)
      model_name = model[:name]
      model_var = model_name.downcase
      
      # Update get_#{model_var}s method
      if @api_features[:pagination]
        controller_content.gsub!(
          /async def get_#{model_var}s\(\s*skip: int = Query\(0, ge=0\),\s*limit: int = Query\(100, ge=1, le=100\),/,
          "async def get_#{model_var}s(\n    page_params: PageParams = Depends(),"
        )
        
        controller_content.gsub!(
          /# Apply pagination\s*cursor = db\.#{model_var}s\.find\(query\)\.skip\(skip\)\.limit\(limit\)\s*#{model_var}s = await cursor\.to_list\(length=limit\)\s*\n\s*return #{model_var}s/,
          "# Apply pagination\n    return await paginate_mongodb(db.#{model_var}s, query, page_params)"
        )
      end
      
      if @api_features[:sorting]
        controller_content.gsub!(
          /async def get_#{model_var}s\(\s*(page_params: PageParams = Depends\(\),)?/,
          "async def get_#{model_var}s(\n    \\1\n    sort_params: SortParams = Depends(),"
        )
        
        controller_content.gsub!(
          /# Get total count for pagination\s*total = await db\.#{model_var}s\.count_documents\(query\)/,
          "# Apply sorting\n    sort = get_mongodb_sort(sort_params)\n    \n    # Get total count for pagination\n    total = await db.#{model_var}s.count_documents(query)"
        )
        
        controller_content.gsub!(
          /cursor = db\.#{model_var}s\.find\(query\)\.skip/,
          "cursor = db.#{model_var}s.find(query).sort(sort).skip"
        )
      end
      
      if @api_features[:filtering]
        controller_content.gsub!(
          /async def get_#{model_var}s\(\s*(page_params: PageParams = Depends\(\),)?(\s*sort_params: SortParams = Depends\(\),)?/,
          "async def get_#{model_var}s(\n    \\1\\2\n    filter_params: FilterParams = Depends(),"
        )
        
        controller_content.gsub!(
          /# Base query\s*query = \{\}/,
          "# Base query\n    query = {}\n    \n    # Apply advanced filtering\n    filter_query = get_mongodb_filter(filter_params)\n    query.update(filter_query)"
        )
      end
    end
    
    def update_fastapi_pony_controller(controller_content, model)
      # Similar implementation for Pony ORM
    end
    
    def update_fastapi_peewee_controller(controller_content, model)
      # Similar implementation for Peewee ORM
    end
    
    def generate_flask_api_features
      log_info("Generating Flask API features")
      
      # Implementation for Flask API features
      # ...
    end
    
    def generate_django_api_features
      log_info("Generating Django API features")
      
      # Implementation for Django API features
      # ...
    end
  end
end 