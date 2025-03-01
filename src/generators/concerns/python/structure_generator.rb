require 'fileutils'

module Tenant
  module PythonStructureGenerator
    def setup_target
      log_info("Setting up target directory: #{@python_path}")
      FileUtils.mkdir_p(@python_path)
    end
    
    def create_python_app
      log_info("Creating Python application structure")
      
      # Create package structure
      create_directory_structure
      
      # Create configuration files
      create_requirements_txt
      create_pyproject_toml
      create_readme
      create_env_file
      
      # Create application files based on framework
      case @framework_type.to_s.downcase
      when "fastapi"
        create_fastapi_app
      when "flask"
        create_flask_app
      when "django"
        create_django_app
      end
      
      # Create batch job handlers if configured
      create_batch_job_handlers if @batch_jobs && @batch_jobs.any?
      
      log_info("Python application structure created")
    end
    
    def create_directory_structure
      log_info("Creating directory structure")
      
      # Common directories for all frameworks
      common_dirs = [
        "tests",
        "docs"
      ]
      
      # Framework-specific directories
      framework_dirs = case @framework_type.to_s.downcase
      when "fastapi"
        [
          "app",
          "app/api",
          "app/api/endpoints",
          "app/core",
          "app/db",
          "app/models",
          "app/schemas",
          "app/services",
          "app/utils"
        ]
      when "flask"
        [
          "app",
          "app/api",
          "app/models",
          "app/schemas",
          "app/services",
          "app/utils",
          "app/extensions"
        ]
      when "django"
        [
          "config",
          "api",
          "api/models",
          "api/serializers",
          "api/views",
          "api/tests"
        ]
      end
      
      # Create batch job directories if needed
      if @batch_jobs && @batch_jobs.any?
        case @framework_type.to_s.downcase
        when "fastapi"
          framework_dirs.concat(["app/tasks", "app/worker"])
        when "flask"
          framework_dirs.concat(["app/tasks", "app/worker"])
        when "django"
          framework_dirs.push("tasks")
        end
      end
      
      # Create all directories
      (common_dirs + framework_dirs).each do |dir|
        dir_path = "#{@python_path}/#{dir}"
        FileUtils.mkdir_p(dir_path)
        
        # Create __init__.py files for Python packages
        if dir.start_with?("app/") || dir == "app" || dir.start_with?("api/") || dir == "api"
          File.write("#{dir_path}/__init__.py", "")
        end
      end
      
      log_info("Directory structure created")
    end
    
    def create_readme
      log_info("Creating README.md")
      
      readme_content = <<~MARKDOWN
        # #{File.basename(@python_path).capitalize} API

        This is a generated Python API microservice using #{@framework_type.capitalize} and #{@database_type.capitalize}.

        ## Features

        - RESTful API endpoints for all models
        - Database integration with #{@database_type.capitalize}
        - API documentation with Swagger/OpenAPI
        #{@batch_jobs && @batch_jobs.any? ? "- Background task processing with Celery" : ""}
        #{@api_features[:pagination] ? "- Pagination support" : ""}
        #{@api_features[:sorting] ? "- Sorting support" : ""}
        #{@api_features[:filtering] ? "- Filtering support" : ""}

        ## Getting Started

        ### Prerequisites

        - Python 3.9+
        - pip
        #{@batch_jobs && @batch_jobs.any? ? "- Redis (for Celery)" : ""}

        ### Installation

        1. Clone the repository
        2. Create a virtual environment:
           ```
           python -m venv venv
           source venv/bin/activate  # On Windows: venv\\Scripts\\activate
           ```
        3. Install dependencies:
           ```
           pip install -r requirements.txt
           ```
        4. Set up environment variables:
           ```
           cp .env.example .env
           # Edit .env with your configuration
           ```

        ### Running the Application

        ```
        #{case @framework_type.to_s.downcase
        when "fastapi"
          "uvicorn app.main:app --reload"
        when "flask"
          "flask run"
        when "django"
          "python manage.py runserver"
        end}
        ```

        #{if @batch_jobs && @batch_jobs.any?
        <<~CELERY
        ### Running Background Tasks

        ```
        celery -A #{case @framework_type.to_s.downcase
        when "fastapi", "flask"
          "app.worker"
        when "django"
          "config"
        end} worker --loglevel=info
        ```
        CELERY
        end}

        ## API Documentation

        #{case @framework_type.to_s.downcase
        when "fastapi"
          "API documentation is available at `/docs` or `/redoc` when the application is running."
        when "flask"
          "API documentation is available at `/swagger-ui` when the application is running."
        when "django"
          "API documentation is available at `/api/docs/` when the application is running."
        end}

        ## Testing

        ```
        pytest
        ```

        ## License

        MIT
      MARKDOWN
      
      File.write("#{@python_path}/README.md", readme_content)
      
      log_info("Created README.md")
    end
    
    def create_env_file
      log_info("Creating .env.example file")
      
      env_content = <<~ENV
        # Application Settings
        DEBUG=True
        SECRET_KEY=your-secret-key-here
        ALLOWED_HOSTS=localhost,127.0.0.1

        # Database Settings
        #{case @database_type.to_s.downcase
        when "sqlalchemy", "peewee"
          "DATABASE_URL=postgresql://postgres:postgres@localhost:5432/#{File.basename(@python_path).gsub('-', '_')}"
        when "django-orm"
          "DATABASE_URL=postgresql://postgres:postgres@localhost:5432/#{File.basename(@python_path).gsub('-', '_')}"
        when "mongodb"
          "MONGODB_URL=mongodb://localhost:27017/\nMONGODB_DB=#{File.basename(@python_path).gsub('-', '_')}"
        when "pony"
          "DATABASE_URL=postgresql://postgres:postgres@localhost:5432/#{File.basename(@python_path).gsub('-', '_')}"
        end}

        #{if @batch_jobs && @batch_jobs.any?
        <<~CELERY_ENV
        # Celery Settings
        CELERY_BROKER_URL=redis://localhost:6379/0
        CELERY_RESULT_BACKEND=redis://localhost:6379/0
        CELERY_ENV
        end}
      ENV
      
      File.write("#{@python_path}/.env.example", env_content)
      
      log_info("Created .env.example file")
    end
  end
end 