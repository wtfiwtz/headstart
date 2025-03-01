module Tenant
  module PythonCeleryHandler
    def initialize_celery_config
      @celery_config = {
        broker_url: 'redis://localhost:6379/0',
        result_backend: 'redis://localhost:6379/0',
        task_serializer: 'json',
        accept_content: ['json'],
        result_serializer: 'json',
        enable_utc: true,
        worker_concurrency: 4,
        task_acks_late: true,
        task_reject_on_worker_lost: true,
        task_time_limit: 30 * 60,  # 30 minutes
        task_soft_time_limit: 15 * 60  # 15 minutes
      }

      @batch_jobs ||= []
      if @config && @config[:batch_jobs]
        @batch_jobs = @config[:batch_jobs]
      end
    end

    def generate_celery_setup
      return if @batch_jobs.empty?

      log "Generating Celery setup for batch jobs"
      
      # Create directories
      FileUtils.mkdir_p(File.join(@app_path, 'app', 'tasks'))
      FileUtils.mkdir_p(File.join(@app_path, 'app', 'workers'))
      
      # Add dependencies
      add_celery_dependencies
      
      # Generate configuration
      generate_celery_config
      
      # Generate task modules
      generate_task_modules
      
      # Generate worker configuration
      generate_worker_config
      
      # Update app with Celery
      update_app_with_celery
    end

    def add_celery_dependencies
      requirements_path = File.join(@app_path, 'requirements.txt')
      
      if File.exist?(requirements_path)
        requirements = File.read(requirements_path)
        
        # Add Celery and Redis dependencies if not already present
        unless requirements.include?('celery')
          requirements << "\ncelery>=5.2.7,<6.0.0\n"
        end
        
        unless requirements.include?('redis')
          requirements << "redis>=4.5.1,<5.0.0\n"
        end
        
        File.write(requirements_path, requirements)
      else
        # Create requirements.txt if it doesn't exist
        File.write(requirements_path, "celery>=5.2.7,<6.0.0\nredis>=4.5.1,<5.0.0\n")
      end
    end

    def generate_celery_config
      celery_config_path = File.join(@app_path, 'app', 'celery_config.py')
      
      celery_config_content = <<~PYTHON
        # Celery configuration
        broker_url = '#{@celery_config[:broker_url]}'
        result_backend = '#{@celery_config[:result_backend]}'
        
        # Serialization
        task_serializer = '#{@celery_config[:task_serializer]}'
        accept_content = #{@celery_config[:accept_content]}
        result_serializer = '#{@celery_config[:result_serializer]}'
        
        # Time and scheduling
        enable_utc = #{@celery_config[:enable_utc]}
        
        # Worker settings
        worker_concurrency = #{@celery_config[:worker_concurrency]}
        task_acks_late = #{@celery_config[:task_acks_late]}
        task_reject_on_worker_lost = #{@celery_config[:task_reject_on_worker_lost]}
        
        # Task execution limits
        task_time_limit = #{@celery_config[:task_time_limit]}  # 30 minutes
        task_soft_time_limit = #{@celery_config[:task_soft_time_limit]}  # 15 minutes
      PYTHON
      
      File.write(celery_config_path, celery_config_content)
    end

    def generate_task_modules
      # Create __init__.py in tasks directory
      File.write(File.join(@app_path, 'app', 'tasks', '__init__.py'), '')
      
      # Create celery.py for Celery app initialization
      celery_app_path = File.join(@app_path, 'app', 'tasks', 'celery.py')
      
      celery_app_content = <<~PYTHON
        from celery import Celery

        # Initialize Celery app
        app = Celery('app')
        
        # Load configuration from module
        app.config_from_object('app.celery_config')
        
        # Auto-discover tasks in all registered app modules
        app.autodiscover_tasks(['app.tasks'])
        
        @app.task(bind=True)
        def debug_task(self):
            print(f'Request: {self.request!r}')
      PYTHON
      
      File.write(celery_app_path, celery_app_content)
      
      # Generate task files for each batch job
      @batch_jobs.each do |job|
        job_name = job[:name].to_s.downcase
        job_description = job[:description] || "Process #{job_name} job"
        processing_time = job[:processing_time] || 1000  # Default to 1 second
        
        task_file_path = File.join(@app_path, 'app', 'tasks', "#{job_name}.py")
        
        task_content = <<~PYTHON
          import time
          import random
          from celery import shared_task
          from celery.utils.log import get_task_logger

          logger = get_task_logger(__name__)

          @shared_task(
              name='tasks.#{job_name}',
              bind=True,
              max_retries=3,
              default_retry_delay=300,  # 5 minutes
              acks_late=True
          )
          def #{job_name}(self, **kwargs):
              """
              #{job_description}
              
              Args:
                  **kwargs: Job parameters
                  
              Returns:
                  dict: Result of the job execution
              """
              job_id = self.request.id
              logger.info(f"Starting #{job_name} job {job_id} with parameters: {kwargs}")
              
              try:
                  # Simulate job processing
                  processing_time_ms = #{processing_time}
                  processing_time_s = processing_time_ms / 1000
                  
                  # Add some randomness to processing time
                  processing_time_s = processing_time_s * (0.8 + 0.4 * random.random())
                  
                  logger.info(f"Processing #{job_name} job for {processing_time_s:.2f} seconds")
                  time.sleep(processing_time_s)
                  
                  # Simulate occasional failures (10% chance)
                  if random.random() < 0.1:
                      raise Exception("Random job failure for testing retry mechanism")
                  
                  result = {
                      "job_id": job_id,
                      "status": "completed",
                      "processing_time_ms": int(processing_time_s * 1000),
                      "result": f"Processed #{job_name} successfully",
                      "parameters": kwargs
                  }
                  
                  logger.info(f"Completed #{job_name} job {job_id}")
                  return result
                  
              except Exception as e:
                  logger.error(f"Error processing #{job_name} job {job_id}: {str(e)}")
                  
                  # Retry the job if we haven't exceeded max retries
                  if self.request.retries < self.max_retries:
                      logger.info(f"Retrying #{job_name} job {job_id} ({self.request.retries + 1}/{self.max_retries})")
                      raise self.retry(exc=e)
                  
                  # If we've exceeded max retries, mark as failed
                  return {
                      "job_id": job_id,
                      "status": "failed",
                      "error": str(e),
                      "parameters": kwargs
                  }
          PYTHON
          
          File.write(task_file_path, task_content)
      end
    end

    def generate_worker_config
      # Create Celery worker script
      worker_script_path = File.join(@app_path, 'worker.py')
      
      worker_script_content = <<~PYTHON
        #!/usr/bin/env python
        """
        Celery worker script
        
        Usage:
            python worker.py
        """
        from app.tasks.celery import app

        if __name__ == '__main__':
            app.worker_main(['worker', '--loglevel=info'])
      PYTHON
      
      File.write(worker_script_path, worker_script_content)
      
      # Make worker script executable
      FileUtils.chmod('+x', worker_script_path)
    end

    def update_app_with_celery
      case @framework_type.to_sym
      when :fastapi
        update_fastapi_with_celery
      when :flask
        update_flask_with_celery
      when :django
        update_django_with_celery
      end
    end

    def update_fastapi_with_celery
      # Create task routes for FastAPI
      routes_dir = File.join(@app_path, 'app', 'routes')
      FileUtils.mkdir_p(routes_dir)
      
      # Create tasks.py for task routes
      tasks_routes_path = File.join(routes_dir, 'tasks.py')
      
      tasks_routes_content = <<~PYTHON
        from fastapi import APIRouter, HTTPException, BackgroundTasks
        from celery.result import AsyncResult
        from typing import Dict, Any, Optional
        
        #{@batch_jobs.map { |job| "from app.tasks.#{job[:name].to_s.downcase} import #{job[:name].to_s.downcase}" }.join("\n")}

        router = APIRouter(prefix="/tasks", tags=["tasks"])

        @router.post("/{task_name}")
        async def create_task(task_name: str, payload: Dict[str, Any]):
            """
            Create a new background task
            
            Args:
                task_name: Name of the task to run
                payload: Task parameters
                
            Returns:
                Dict with task_id and status
            """
            task_mapping = {
                #{@batch_jobs.map { |job| "\"#{job[:name].to_s.downcase}\": #{job[:name].to_s.downcase}" }.join(",\n                ")}
            }
            
            if task_name not in task_mapping:
                raise HTTPException(status_code=404, detail=f"Task {task_name} not found")
                
            try:
                task = task_mapping[task_name].delay(**payload)
                return {"task_id": task.id, "status": "pending"}
            except Exception as e:
                raise HTTPException(status_code=500, detail=str(e))

        @router.get("/{task_name}/{task_id}")
        async def get_task_status(task_name: str, task_id: str):
            """
            Get status of a background task
            
            Args:
                task_name: Name of the task
                task_id: ID of the task
                
            Returns:
                Dict with task status and result if available
            """
            task = AsyncResult(task_id)
            
            response = {
                "task_id": task_id,
                "status": task.status,
            }
            
            if task.status == 'SUCCESS':
                response["result"] = task.result
            elif task.status == 'FAILURE':
                response["error"] = str(task.result)
                
            return response
      PYTHON
      
      File.write(tasks_routes_path, tasks_routes_content)
      
      # Update main.py to include task routes
      main_path = File.join(@app_path, 'main.py')
      
      if File.exist?(main_path)
        main_content = File.read(main_path)
        
        # Add import for task routes if not already present
        unless main_content.include?('from app.routes.tasks import router as tasks_router')
          import_line = "from app.routes.tasks import router as tasks_router"
          main_content = main_content.gsub(/(from fastapi import FastAPI.*$)/, "\\1\n#{import_line}")
        end
        
        # Add task routes to app if not already present
        unless main_content.include?('app.include_router(tasks_router)')
          include_line = "app.include_router(tasks_router)"
          main_content = main_content.gsub(/(app = FastAPI\(.*?\).*$)/, "\\1\n#{include_line}")
        end
        
        File.write(main_path, main_content)
      end
    end

    def update_flask_with_celery
      # Create task routes for Flask
      routes_dir = File.join(@app_path, 'app', 'routes')
      FileUtils.mkdir_p(routes_dir)
      
      # Create tasks.py for task routes
      tasks_routes_path = File.join(routes_dir, 'tasks.py')
      
      tasks_routes_content = <<~PYTHON
        from flask import Blueprint, request, jsonify
        from celery.result import AsyncResult
        
        #{@batch_jobs.map { |job| "from app.tasks.#{job[:name].to_s.downcase} import #{job[:name].to_s.downcase}" }.join("\n")}

        tasks_bp = Blueprint('tasks', __name__, url_prefix='/tasks')

        @tasks_bp.route('/<task_name>', methods=['POST'])
        def create_task(task_name):
            """
            Create a new background task
            
            Args:
                task_name: Name of the task to run
                
            Returns:
                Dict with task_id and status
            """
            payload = request.get_json() or {}
            
            task_mapping = {
                #{@batch_jobs.map { |job| "\"#{job[:name].to_s.downcase}\": #{job[:name].to_s.downcase}" }.join(",\n                ")}
            }
            
            if task_name not in task_mapping:
                return jsonify({"error": f"Task {task_name} not found"}), 404
                
            try:
                task = task_mapping[task_name].delay(**payload)
                return jsonify({"task_id": task.id, "status": "pending"})
            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @tasks_bp.route('/<task_name>/<task_id>', methods=['GET'])
        def get_task_status(task_name, task_id):
            """
            Get status of a background task
            
            Args:
                task_name: Name of the task
                task_id: ID of the task
                
            Returns:
                Dict with task status and result if available
            """
            task = AsyncResult(task_id)
            
            response = {
                "task_id": task_id,
                "status": task.status,
            }
            
            if task.status == 'SUCCESS':
                response["result"] = task.result
            elif task.status == 'FAILURE':
                response["error"] = str(task.result)
                
            return jsonify(response)
      PYTHON
      
      File.write(tasks_routes_path, tasks_routes_content)
      
      # Update app/__init__.py to include task routes
      app_init_path = File.join(@app_path, 'app', '__init__.py')
      
      if File.exist?(app_init_path)
        app_init_content = File.read(app_init_path)
        
        # Add import for task routes if not already present
        unless app_init_content.include?('from app.routes.tasks import tasks_bp')
          app_init_content += "\nfrom app.routes.tasks import tasks_bp\n"
        end
        
        # Add task routes to app if not already present
        unless app_init_content.include?('app.register_blueprint(tasks_bp)')
          app_init_content += "app.register_blueprint(tasks_bp)\n"
        end
        
        File.write(app_init_path, app_init_content)
      end
    end

    def update_django_with_celery
      # Create a Django app for tasks if it doesn't exist
      tasks_app_dir = File.join(@app_path, 'tasks')
      FileUtils.mkdir_p(tasks_app_dir)
      FileUtils.mkdir_p(File.join(tasks_app_dir, 'migrations'))
      
      # Create __init__.py files
      File.write(File.join(tasks_app_dir, '__init__.py'), '')
      File.write(File.join(tasks_app_dir, 'migrations', '__init__.py'), '')
      
      # Create apps.py
      apps_path = File.join(tasks_app_dir, 'apps.py')
      apps_content = <<~PYTHON
        from django.apps import AppConfig

        class TasksConfig(AppConfig):
            default_auto_field = 'django.db.models.BigAutoField'
            name = 'tasks'
      PYTHON
      File.write(apps_path, apps_content)
      
      # Create views.py for task endpoints
      views_path = File.join(tasks_app_dir, 'views.py')
      views_content = <<~PYTHON
        from django.http import JsonResponse
        from django.views.decorators.csrf import csrf_exempt
        from django.views.decorators.http import require_http_methods
        import json
        from celery.result import AsyncResult
        
        #{@batch_jobs.map { |job| "from app.tasks.#{job[:name].to_s.downcase} import #{job[:name].to_s.downcase}" }.join("\n")}

        @csrf_exempt
        @require_http_methods(["POST"])
        def create_task(request, task_name):
            """
            Create a new background task
            
            Args:
                request: HTTP request
                task_name: Name of the task to run
                
            Returns:
                JsonResponse with task_id and status
            """
            try:
                payload = json.loads(request.body)
            except json.JSONDecodeError:
                payload = {}
            
            task_mapping = {
                #{@batch_jobs.map { |job| "\"#{job[:name].to_s.downcase}\": #{job[:name].to_s.downcase}" }.join(",\n                ")}
            }
            
            if task_name not in task_mapping:
                return JsonResponse({"error": f"Task {task_name} not found"}, status=404)
                
            try:
                task = task_mapping[task_name].delay(**payload)
                return JsonResponse({"task_id": task.id, "status": "pending"})
            except Exception as e:
                return JsonResponse({"error": str(e)}, status=500)

        @require_http_methods(["GET"])
        def get_task_status(request, task_name, task_id):
            """
            Get status of a background task
            
            Args:
                request: HTTP request
                task_name: Name of the task
                task_id: ID of the task
                
            Returns:
                JsonResponse with task status and result if available
            """
            task = AsyncResult(task_id)
            
            response = {
                "task_id": task_id,
                "status": task.status,
            }
            
            if task.status == 'SUCCESS':
                response["result"] = task.result
            elif task.status == 'FAILURE':
                response["error"] = str(task.result)
                
            return JsonResponse(response)
      PYTHON
      File.write(views_path, views_content)
      
      # Create urls.py for task routes
      urls_path = File.join(tasks_app_dir, 'urls.py')
      urls_content = <<~PYTHON
        from django.urls import path
        from . import views

        urlpatterns = [
            path('<str:task_name>/', views.create_task, name='create_task'),
            path('<str:task_name>/<str:task_id>/', views.get_task_status, name='get_task_status'),
        ]
      PYTHON
      File.write(urls_path, urls_content)
      
      # Update project urls.py to include task routes
      project_name = File.basename(@app_path)
      project_urls_path = File.join(@app_path, project_name, 'urls.py')
      
      if File.exist?(project_urls_path)
        project_urls_content = File.read(project_urls_path)
        
        # Add import for task urls if not already present
        unless project_urls_content.include?('path("tasks/"')
          # Find the urlpatterns list
          if project_urls_content =~ /urlpatterns\s*=\s*\[/
            # Add the tasks URL to the urlpatterns list
            project_urls_content.gsub!(/urlpatterns\s*=\s*\[/, "urlpatterns = [\n    path('tasks/', include('tasks.urls')),")
            
            # Add the include import if not already present
            unless project_urls_content.include?('from django.urls import path, include')
              project_urls_content.gsub!(/from django\.urls import path/, 'from django.urls import path, include')
            end
            
            File.write(project_urls_path, project_urls_content)
          end
        end
      end
      
      # Update settings.py to include the tasks app
      settings_path = File.join(@app_path, project_name, 'settings.py')
      
      if File.exist?(settings_path)
        settings_content = File.read(settings_path)
        
        # Add the tasks app to INSTALLED_APPS if not already present
        unless settings_content.include?("'tasks'")
          settings_content.gsub!(/INSTALLED_APPS\s*=\s*\[([^\]]*)\]/) do |match|
            installed_apps = $1
            "INSTALLED_APPS = [#{installed_apps}    'tasks',\n]"
          end
        end
        
        # Add Celery configuration if not already present
        unless settings_content.include?('CELERY_')
          celery_config = <<~PYTHON
            
            # Celery Configuration
            CELERY_BROKER_URL = '#{@celery_config[:broker_url]}'
            CELERY_RESULT_BACKEND = '#{@celery_config[:result_backend]}'
            CELERY_ACCEPT_CONTENT = #{@celery_config[:accept_content]}
            CELERY_TASK_SERIALIZER = '#{@celery_config[:task_serializer]}'
            CELERY_RESULT_SERIALIZER = '#{@celery_config[:result_serializer]}'
            CELERY_TIMEZONE = 'UTC'
          PYTHON
          
          settings_content += celery_config
        end
        
        File.write(settings_path, settings_content)
      end
      
      # Create celery.py in the project directory
      project_celery_path = File.join(@app_path, project_name, 'celery.py')
      project_celery_content = <<~PYTHON
        import os
        from celery import Celery

        # Set the default Django settings module
        os.environ.setdefault('DJANGO_SETTINGS_MODULE', '#{project_name}.settings')

        app = Celery('#{project_name}')

        # Use Django settings for Celery
        app.config_from_object('django.conf:settings', namespace='CELERY')

        # Auto-discover tasks in all installed apps
        app.autodiscover_tasks()

        @app.task(bind=True)
        def debug_task(self):
            print(f'Request: {self.request!r}')
      PYTHON
      File.write(project_celery_path, project_celery_content)
      
      # Update project __init__.py to include Celery
      project_init_path = File.join(@app_path, project_name, '__init__.py')
      project_init_content = <<~PYTHON
        # Import Celery app
        from .celery import app as celery_app

        __all__ = ('celery_app',)
      PYTHON
      File.write(project_init_path, project_init_content)
    end
  end
end 