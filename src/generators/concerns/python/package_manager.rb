module Tenant
  module PythonPackageManager
    def create_requirements_txt
      log_info("Creating requirements.txt")
      
      # Base dependencies
      dependencies = [
        "python-dotenv==1.0.0",
        "pydantic==2.5.2"
      ]
      
      # Framework-specific dependencies
      case @framework_type.to_s.downcase
      when "fastapi"
        dependencies.concat([
          "fastapi==0.104.1",
          "uvicorn==0.24.0",
          "starlette==0.27.0"
        ])
      when "flask"
        dependencies.concat([
          "flask==2.3.3",
          "flask-restful==0.3.10",
          "gunicorn==21.2.0"
        ])
      when "django"
        dependencies.concat([
          "django==4.2.7",
          "djangorestframework==3.14.0",
          "django-filter==23.3"
        ])
      end
      
      # Database-specific dependencies
      case @database_type.to_s.downcase
      when "sqlalchemy"
        dependencies.concat([
          "sqlalchemy==2.0.23",
          "alembic==1.12.1",
          "psycopg2-binary==2.9.9"  # For PostgreSQL
        ])
      when "django-orm"
        # Django ORM is included with Django
      when "pony"
        dependencies.push("pony==0.7.16")
      when "peewee"
        dependencies.push("peewee==3.17.0")
      when "mongodb"
        dependencies.push("motor==3.3.1")  # Async MongoDB driver
      end
      
      # API features dependencies
      if @api_features[:pagination] || @api_features[:sorting] || @api_features[:filtering]
        dependencies.push("fastapi-pagination==0.12.12") if @framework_type.to_s.downcase == "fastapi"
      end
      
      # Batch job dependencies
      if @batch_jobs && @batch_jobs.any?
        dependencies.concat([
          "celery==5.3.4",
          "redis==5.0.1"
        ])
      end
      
      # Testing dependencies
      dependencies.concat([
        "pytest==7.4.3",
        "pytest-asyncio==0.21.1"
      ])
      
      # Write requirements.txt
      File.write("#{@python_path}/requirements.txt", dependencies.join("\n"))
      
      log_info("Created requirements.txt with #{dependencies.length} dependencies")
    end
    
    def create_pyproject_toml
      log_info("Creating pyproject.toml")
      
      project_name = File.basename(@python_path).gsub('-', '_')
      
      pyproject_content = <<~TOML
        [build-system]
        requires = ["setuptools>=42", "wheel"]
        build-backend = "setuptools.build_meta"

        [project]
        name = "#{project_name}"
        version = "0.1.0"
        description = "Generated Python API microservice"
        readme = "README.md"
        requires-python = ">=3.9"
        license = {text = "MIT"}
        
        [tool.pytest.ini_options]
        testpaths = ["tests"]
        python_files = "test_*.py"
      TOML
      
      File.write("#{@python_path}/pyproject.toml", pyproject_content)
      
      log_info("Created pyproject.toml")
    end
  end
end 