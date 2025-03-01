module Tenant
  module PythonRouteGenerator
    def generate_routes
      log_info("Generating routes")
      
      # Generate routes based on framework
      case @framework_type.to_s.downcase
      when "fastapi"
        # Routes are already generated in the controllers for FastAPI
        log_info("Routes are included in the FastAPI controllers")
      when "flask"
        generate_flask_routes
      when "django"
        generate_django_routes
      end
      
      log_info("Routes generated")
    end
    
    def generate_flask_routes
      log_info("Generating Flask routes")
      
      # Create routes directory if it doesn't exist
      FileUtils.mkdir_p("#{@python_path}/app/routes")
      
      # Create __init__.py
      init_content = <<~PYTHON
        from flask import Blueprint
        #{@models.map { |m| "from app.routes.#{m[:name].downcase} import #{m[:name].downcase}_bp" }.join("\n")}

        def register_routes(app):
            #{@models.map { |m| "app.register_blueprint(#{m[:name].downcase}_bp, url_prefix='/api/#{m[:name].downcase}s')" }.join("\n    ")}
      PYTHON
      
      File.write("#{@python_path}/app/routes/__init__.py", init_content)
      
      # Generate each route
      @models.each do |model|
        generate_flask_route(model)
      end
    end
    
    def generate_flask_route(model)
      model_name = model[:name]
      model_var = model_name.downcase
      route_file = "#{@python_path}/app/routes/#{model_var}.py"
      
      log_info("Generating Flask route: #{model_name}")
      
      # Generate route content
      route_content = <<~PYTHON
        from flask import Blueprint, request, jsonify
        from app.models.#{model_var} import #{model_name.capitalize}
        from app.schemas.#{model_var} import #{model_name.capitalize}Schema
        from app.extensions import db

        #{model_var}_bp = Blueprint('#{model_var}', __name__)

        @#{model_var}_bp.route('/', methods=['GET'])
        def get_#{model_var}s():
            """
            Get all #{model_var}s with optional filtering
            """
            # Get query parameters
            page = request.args.get('page', 1, type=int)
            per_page = request.args.get('per_page', 10, type=int)
            
            # Base query
            query = #{model_name.capitalize}.query
            
            # Apply filters if provided
            #{model[:attributes] ? model[:attributes].map { |attr| "#{attr[:name]} = request.args.get('#{attr[:name]}')\nif #{attr[:name]} is not None:\n    query = query.filter(#{model_name.capitalize}.#{attr[:name]} == #{attr[:name]})" }.join("\n    ") : ""}
            
            # Apply pagination
            paginated = query.paginate(page=page, per_page=per_page)
            
            # Serialize results
            result = {
                'items': #{model_name.capitalize}Schema(many=True).dump(paginated.items),
                'total': paginated.total,
                'page': page,
                'size': per_page,
                'pages': paginated.pages
            }
            
            return jsonify(result)

        @#{model_var}_bp.route('/', methods=['POST'])
        def create_#{model_var}():
            """
            Create a new #{model_var}
            """
            data = request.get_json()
            
            # Validate data
            errors = #{model_name.capitalize}Schema().validate(data)
            if errors:
                return jsonify(errors), 400
                
            # Create new #{model_var}
            #{model_var} = #{model_name.capitalize}(**data)
            
            db.session.add(#{model_var})
            db.session.commit()
            
            return #{model_name.capitalize}Schema().dump(#{model_var}), 201

        @#{model_var}_bp.route('/<int:#{model_var}_id>', methods=['GET'])
        def get_#{model_var}(#{model_var}_id):
            """
            Get a specific #{model_var} by ID
            """
            #{model_var} = #{model_name.capitalize}.query.get(#{model_var}_id)
            
            if #{model_var} is None:
                return jsonify({'error': '#{model_name.capitalize} not found'}), 404
                
            return #{model_name.capitalize}Schema().dump(#{model_var})

        @#{model_var}_bp.route('/<int:#{model_var}_id>', methods=['PUT'])
        def update_#{model_var}(#{model_var}_id):
            """
            Update a #{model_var}
            """
            #{model_var} = #{model_name.capitalize}.query.get(#{model_var}_id)
            
            if #{model_var} is None:
                return jsonify({'error': '#{model_name.capitalize} not found'}), 404
                
            data = request.get_json()
            
            # Update model with provided values
            for key, value in data.items():
                if hasattr(#{model_var}, key):
                    setattr(#{model_var}, key, value)
                    
            db.session.commit()
            
            return #{model_name.capitalize}Schema().dump(#{model_var})

        @#{model_var}_bp.route('/<int:#{model_var}_id>', methods=['DELETE'])
        def delete_#{model_var}(#{model_var}_id):
            """
            Delete a #{model_var}
            """
            #{model_var} = #{model_name.capitalize}.query.get(#{model_var}_id)
            
            if #{model_var} is None:
                return jsonify({'error': '#{model_name.capitalize} not found'}), 404
                
            db.session.delete(#{model_var})
            db.session.commit()
            
            return jsonify({'status': 'success', 'message': '#{model_name.capitalize} deleted successfully'})
      PYTHON
      
      # Write route file
      File.write(route_file, route_content)
      
      log_info("Generated Flask route: #{model_name}")
    end
    
    def generate_django_routes
      log_info("Generating Django routes")
      
      # Create urls.py in the api directory
      api_urls_content = <<~PYTHON
        from django.urls import path, include

        urlpatterns = [
            #{@models.map { |m| "path('#{m[:name].downcase}s/', include('api.urls.#{m[:name].downcase}'))" }.join(",\n    ")}
        ]
      PYTHON
      
      # Create urls directory if it doesn't exist
      FileUtils.mkdir_p("#{@python_path}/api/urls")
      
      # Write api/urls.py
      File.write("#{@python_path}/api/urls.py", api_urls_content)
      
      # Create __init__.py in the urls directory
      File.write("#{@python_path}/api/urls/__init__.py", "")
      
      # Generate each route
      @models.each do |model|
        generate_django_route(model)
      end
    end
    
    def generate_django_route(model)
      model_name = model[:name]
      model_var = model_name.downcase
      route_file = "#{@python_path}/api/urls/#{model_var}.py"
      
      log_info("Generating Django route: #{model_name}")
      
      # Generate route content
      route_content = <<~PYTHON
        from django.urls import path
        from api.views.#{model_var} import #{model_name.capitalize}ViewSet

        urlpatterns = [
            path('', #{model_name.capitalize}ViewSet.as_view({'get': 'list', 'post': 'create'}), name='#{model_var}-list'),
            path('<int:pk>/', #{model_name.capitalize}ViewSet.as_view({'get': 'retrieve', 'put': 'update', 'delete': 'destroy'}), name='#{model_var}-detail'),
        ]
      PYTHON
      
      # Write route file
      File.write(route_file, route_content)
      
      log_info("Generated Django route: #{model_name}")
    end
  end
end 