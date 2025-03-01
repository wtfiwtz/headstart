module Tenant
  module PythonTemplateHandler
    def create_fastapi_app
      log_info("Creating FastAPI application")
      
      # Create main.py
      create_fastapi_main
      
      # Create database connection
      create_fastapi_db_connection
      
      # Create core modules
      create_fastapi_core_modules
      
      # Create API router
      create_fastapi_api_router
      
      log_info("FastAPI application created")
    end
    
    def create_fastapi_main
      log_info("Creating FastAPI main.py")
      
      main_content = <<~PYTHON
        from fastapi import FastAPI
        from fastapi.middleware.cors import CORSMiddleware
        from app.api.api import api_router
        from app.core.config import settings

        app = FastAPI(
            title=settings.PROJECT_NAME,
            description=settings.PROJECT_DESCRIPTION,
            version=settings.VERSION,
            openapi_url=f"{settings.API_V1_STR}/openapi.json",
            docs_url="/docs",
            redoc_url="/redoc",
        )

        # Set up CORS middleware
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.CORS_ORIGINS,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

        # Include API router
        app.include_router(api_router, prefix=settings.API_V1_STR)

        @app.get("/")
        def root():
            """
            Root endpoint - Health check
            """
            return {"status": "ok", "message": "Welcome to the API"}
      PYTHON
      
      File.write("#{@python_path}/app/main.py", main_content)
      
      log_info("Created FastAPI main.py")
    end
    
    def create_fastapi_db_connection
      log_info("Creating FastAPI database connection")
      
      # Create database connection based on database type
      case @database_type.to_s.downcase
      when "sqlalchemy"
        create_sqlalchemy_connection
      when "mongodb"
        create_mongodb_connection
      when "pony"
        create_pony_connection
      when "peewee"
        create_peewee_connection
      end
      
      log_info("Created FastAPI database connection")
    end
    
    def create_sqlalchemy_connection
      # Create database.py
      db_content = <<~PYTHON
        from sqlalchemy import create_engine
        from sqlalchemy.ext.declarative import declarative_base
        from sqlalchemy.orm import sessionmaker
        from app.core.config import settings

        engine = create_engine(settings.DATABASE_URL)
        SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
        Base = declarative_base()

        # Dependency
        def get_db():
            db = SessionLocal()
            try:
                yield db
            finally:
                db.close()
      PYTHON
      
      File.write("#{@python_path}/app/db/database.py", db_content)
      
      # Create session.py
      session_content = <<~PYTHON
        from typing import Generator
        from app.db.database import SessionLocal

        def get_db() -> Generator:
            db = SessionLocal()
            try:
                yield db
            finally:
                db.close()
      PYTHON
      
      File.write("#{@python_path}/app/db/session.py", session_content)
      
      # Create init_db.py
      init_db_content = <<~PYTHON
        import logging
        from sqlalchemy.orm import Session
        from app.db.database import Base, engine

        logging.basicConfig(level=logging.INFO)
        logger = logging.getLogger(__name__)

        def init_db() -> None:
            # Create tables
            Base.metadata.create_all(bind=engine)
            logger.info("Database tables created")
      PYTHON
      
      File.write("#{@python_path}/app/db/init_db.py", init_db_content)
    end
    
    def create_mongodb_connection
      # Create database.py
      db_content = <<~PYTHON
        import motor.motor_asyncio
        from app.core.config import settings

        client = motor.motor_asyncio.AsyncIOMotorClient(settings.MONGODB_URL)
        db = client[settings.MONGODB_DB]
      PYTHON
      
      File.write("#{@python_path}/app/db/database.py", db_content)
    end
    
    def create_pony_connection
      # Create database.py
      db_content = <<~PYTHON
        from pony.orm import Database, db_session
        from app.core.config import settings

        db = Database()

        def connect_db():
            db.bind(provider='postgres', dsn=settings.DATABASE_URL)
            db.generate_mapping(create_tables=True)
      PYTHON
      
      File.write("#{@python_path}/app/db/database.py", db_content)
    end
    
    def create_peewee_connection
      # Create database.py
      db_content = <<~PYTHON
        from peewee import PostgresqlDatabase
        from app.core.config import settings
        import urllib.parse

        # Parse the DATABASE_URL
        url = urllib.parse.urlparse(settings.DATABASE_URL)
        db_name = url.path[1:]
        db_user = url.username
        db_password = url.password
        db_host = url.hostname
        db_port = url.port or 5432

        db = PostgresqlDatabase(
            db_name,
            user=db_user,
            password=db_password,
            host=db_host,
            port=db_port
        )

        def connect_db():
            db.connect()
      PYTHON
      
      File.write("#{@python_path}/app/db/database.py", db_content)
    end
    
    def create_fastapi_core_modules
      log_info("Creating FastAPI core modules")
      
      # Create config.py
      config_content = <<~PYTHON
        import os
        import secrets
        from typing import List, Optional, Union
        from pydantic import AnyHttpUrl, BaseSettings, validator

        class Settings(BaseSettings):
            API_V1_STR: str = "/api/v1"
            PROJECT_NAME: str = "#{File.basename(@python_path).capitalize} API"
            PROJECT_DESCRIPTION: str = "Generated Python API microservice"
            VERSION: str = "0.1.0"
            SECRET_KEY: str = secrets.token_urlsafe(32)
            ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 8  # 8 days
            
            # CORS
            CORS_ORIGINS: List[AnyHttpUrl] = []
            
            @validator("CORS_ORIGINS", pre=True)
            def assemble_cors_origins(cls, v: Union[str, List[str]]) -> Union[List[str], str]:
                if isinstance(v, str) and not v.startswith("["):
                    return [i.strip() for i in v.split(",")]
                elif isinstance(v, (list, str)):
                    return v
                raise ValueError(v)
            
            # Database
            #{case @database_type.to_s.downcase
            when "sqlalchemy", "peewee", "pony"
              "DATABASE_URL: str = os.getenv(\"DATABASE_URL\", \"postgresql://postgres:postgres@localhost:5432/#{File.basename(@python_path).gsub('-', '_')}\")"
            when "mongodb"
              <<~MONGODB
              MONGODB_URL: str = os.getenv("MONGODB_URL", "mongodb://localhost:27017/")
              MONGODB_DB: str = os.getenv("MONGODB_DB", "#{File.basename(@python_path).gsub('-', '_')}")
              MONGODB
            end}
            
            #{if @batch_jobs && @batch_jobs.any?
            <<~CELERY_CONFIG
            # Celery
            CELERY_BROKER_URL: str = os.getenv("CELERY_BROKER_URL", "redis://localhost:6379/0")
            CELERY_RESULT_BACKEND: str = os.getenv("CELERY_RESULT_BACKEND", "redis://localhost:6379/0")
            CELERY_CONFIG
            end}
            
            class Config:
                case_sensitive = True
                env_file = ".env"

        settings = Settings()
      PYTHON
      
      File.write("#{@python_path}/app/core/config.py", config_content)
      
      # Create security.py if needed
      security_content = <<~PYTHON
        from datetime import datetime, timedelta
        from typing import Any, Optional, Union
        from jose import jwt
        from passlib.context import CryptContext
        from app.core.config import settings

        pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

        def create_access_token(subject: Union[str, Any], expires_delta: Optional[timedelta] = None) -> str:
            if expires_delta:
                expire = datetime.utcnow() + expires_delta
            else:
                expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
            
            to_encode = {"exp": expire, "sub": str(subject)}
            encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm="HS256")
            return encoded_jwt

        def verify_password(plain_password: str, hashed_password: str) -> bool:
            return pwd_context.verify(plain_password, hashed_password)

        def get_password_hash(password: str) -> str:
            return pwd_context.hash(password)
      PYTHON
      
      File.write("#{@python_path}/app/core/security.py", security_content)
      
      log_info("Created FastAPI core modules")
    end
    
    def create_fastapi_api_router
      log_info("Creating FastAPI API router")
      
      # Create api.py
      api_content = <<~PYTHON
        from fastapi import APIRouter
        #{@models.map { |m| "from app.api.endpoints import #{m[:name].downcase}" }.join("\n")}

        api_router = APIRouter()
        #{@models.map { |m| "api_router.include_router(#{m[:name].downcase}.router, prefix=\"/#{m[:name].downcase}s\", tags=[\"#{m[:name].capitalize}s\"])" }.join("\n")}
      PYTHON
      
      File.write("#{@python_path}/app/api/api.py", api_content)
      
      log_info("Created FastAPI API router")
    end
    
    def create_flask_app
      log_info("Creating Flask application")
      
      # Implementation for Flask app generation
      # ...
      
      log_info("Flask application created")
    end
    
    def create_django_app
      log_info("Creating Django application")
      
      # Implementation for Django app generation
      # ...
      
      log_info("Django application created")
    end
    
    def create_batch_job_handlers
      log_info("Creating batch job handlers")
      
      case @framework_type.to_s.downcase
      when "fastapi"
        create_fastapi_batch_jobs
      when "flask"
        create_flask_batch_jobs
      when "django"
        create_django_batch_jobs
      end
      
      log_info("Batch job handlers created")
    end
    
    def create_fastapi_batch_jobs
      # Create Celery worker
      worker_content = <<~PYTHON
        import os
        from celery import Celery
        from app.core.config import settings

        celery_app = Celery(
            "worker",
            broker=settings.CELERY_BROKER_URL,
            backend=settings.CELERY_RESULT_BACKEND,
        )

        celery_app.conf.task_routes = {
            "app.tasks.*": {"queue": "main-queue"}
        }

        celery_app.conf.update(
            task_serializer="json",
            accept_content=["json"],
            result_serializer="json",
            timezone="UTC",
            enable_utc=True,
        )
      PYTHON
      
      File.write("#{@python_path}/app/worker.py", worker_content)
      
      # Create tasks module
      tasks_init_content = <<~PYTHON
        from app.worker import celery_app

        __all__ = ["celery_app"]
      PYTHON
      
      File.write("#{@python_path}/app/tasks/__init__.py", tasks_init_content)
      
      # Create example task
      example_task_content = <<~PYTHON
        from app.worker import celery_app
        import logging
        import time

        logger = logging.getLogger(__name__)

        @celery_app.task(name="app.tasks.example.process_data")
        def process_data(data_id: int) -> dict:
            """
            Example task that processes data
            """
            logger.info(f"Processing data with ID: {data_id}")
            
            # Simulate processing time
            time.sleep(5)
            
            result = {"status": "completed", "data_id": data_id, "processed": True}
            logger.info(f"Data processing completed: {result}")
            
            return result
      PYTHON
      
      File.write("#{@python_path}/app/tasks/example.py", example_task_content)
      
      # Create batch job handlers for each model if specified
      @batch_jobs.each do |job|
        job_name = job[:name]
        job_content = <<~PYTHON
          from app.worker import celery_app
          import logging
          import time

          logger = logging.getLogger(__name__)

          @celery_app.task(name="app.tasks.#{job_name}.process")
          def process(job_id: int, **kwargs) -> dict:
              """
              #{job[:description] || "Process #{job_name} job"}
              """
              logger.info(f"Processing #{job_name} job with ID: {job_id}")
              logger.info(f"Parameters: {kwargs}")
              
              # Simulate processing time
              time.sleep(#{job[:processing_time] || 5})
              
              result = {
                  "status": "completed", 
                  "job_id": job_id, 
                  "job_type": "#{job_name}",
                  "processed": True
              }
              
              logger.info(f"#{job_name.capitalize} job processing completed: {result}")
              
              return result
        PYTHON
        
        File.write("#{@python_path}/app/tasks/#{job_name}.py", job_content)
      end
    end
    
    def create_flask_batch_jobs
      # Implementation for Flask batch jobs
      # ...
    end
    
    def create_django_batch_jobs
      # Implementation for Django batch jobs
      # ...
    end
  end
end 