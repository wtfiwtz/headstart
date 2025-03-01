# Python Generator

This directory contains the concerns for generating Python API microservices.

## Structure

The Python generator is organized into separate concerns for maintainability:

- **Configuration Handler**: Manages application configuration
- **Package Manager**: Handles dependencies and package management
- **Application Structure Handler**: Creates the basic application structure
- **Model Generator**: Generates data models
- **Controller Generator**: Creates API controllers
- **Route Generator**: Sets up API routes
- **API Features Handler**: Implements advanced API features
- **Celery Handler**: Sets up background task processing with Celery

## Concerns

### PythonConfigurationHandler

Responsible for initializing and validating configuration settings for the Python application.

### PythonPackageManager

Manages dependencies and package requirements for the Python application.

### PythonApplicationStructureHandler

Creates the basic directory structure and files for the Python application.

### PythonModelGenerator

Generates data models based on the specified database type (SQLAlchemy, MongoDB, etc.).

### PythonControllerGenerator

Creates API controllers for handling HTTP requests and responses.

### PythonRouteGenerator

Sets up API routes for the application.

### PythonApiFeaturesHandler

Implements advanced API features such as pagination, sorting, and filtering.

### PythonCeleryHandler

Sets up background task processing with Celery and Redis.

## Supported Frameworks

- **FastAPI**: Modern, high-performance web framework
- **Flask**: Lightweight WSGI web application framework
- **Django**: Full-featured web framework

## Supported Database Types

- **SQLAlchemy**: SQL toolkit and ORM
- **MongoDB**: NoSQL document database
- **Pony ORM**: Python ORM with query syntax
- **Peewee**: Simple and small ORM
- **Django ORM**: Django's built-in ORM

## API Features

The Python generator supports advanced API features:

### Pagination

```python
# FastAPI example
@router.get("/users")
async def get_users(
    page: int = Query(1, ge=1),
    size: int = Query(10, ge=1, le=100)
):
    skip = (page - 1) * size
    users = await get_users_from_db(skip=skip, limit=size)
    total = await count_users_in_db()
    
    return {
        "data": users,
        "pagination": {
            "total": total,
            "page": page,
            "size": size,
            "pages": math.ceil(total / size)
        }
    }
```

### Sorting

```python
# FastAPI example
@router.get("/users")
async def get_users(
    sort: str = Query(None)
):
    # Parse sort parameter: "name:asc,created_at:desc"
    sort_fields = []
    if sort:
        for field in sort.split(','):
            if ':' in field:
                field_name, direction = field.split(':')
                sort_fields.append((field_name, direction))
    
    users = await get_users_from_db(sort_fields=sort_fields)
    return {"data": users}
```

### Filtering

```python
# FastAPI example
@router.get("/users")
async def get_users(
    filter: str = Query(None)
):
    # Parse filter parameter: "age:gt:18,name:regex:john"
    filter_conditions = {}
    if filter:
        for condition in filter.split(','):
            parts = condition.split(':')
            if len(parts) == 3:
                field, operator, value = parts
                filter_conditions[field] = {"operator": operator, "value": value}
    
    users = await get_users_from_db(filter_conditions=filter_conditions)
    return {"data": users}
```

## Batch Job Handling

The Python generator supports background task processing using Celery with Redis as the message broker:

### Configuration

```yaml
# YAML configuration
batch_jobs:
  - name: process_data
    description: Process data in the background
    processing_time: 5000
  - name: send_emails
    description: Send batch emails to users
    processing_time: 3000
```

### Task Definition

```python
# Generated task
@shared_task(
    name='tasks.process_data',
    bind=True,
    max_retries=3,
    default_retry_delay=300
)
def process_data(self, **kwargs):
    """Process data in the background"""
    job_id = self.request.id
    logger.info(f"Starting process_data job {job_id}")
    
    # Task implementation
    # ...
    
    return {"status": "completed", "result": "Data processed successfully"}
```

### API Integration

```python
# FastAPI example
@router.post("/tasks/{task_name}")
async def create_task(task_name: str, payload: Dict[str, Any]):
    task_mapping = {
        "process_data": process_data,
        "send_emails": send_emails
    }
    
    if task_name not in task_mapping:
        raise HTTPException(status_code=404, detail=f"Task {task_name} not found")
    
    task = task_mapping[task_name].delay(**payload)
    return {"task_id": task.id, "status": "pending"}

@router.get("/tasks/{task_name}/{task_id}")
async def get_task_status(task_name: str, task_id: str):
    task = AsyncResult(task_id)
    
    response = {
        "task_id": task_id,
        "status": task.status,
    }
    
    if task.status == 'SUCCESS':
        response["result"] = task.result
    
    return response
```

## Adding New Features

To add new features to the Python generator:

1. Create a new concern module in `src/generators/concerns/python/`
2. Include the module in `src/generators/frameworks/python/python_generator.rb`
3. Implement the necessary methods in your module
4. Update this README with documentation for your new feature

## Usage Example

```ruby
# Initialize the Python generator
generator = Tenant::PythonGenerator.new

# Configure the generator
generator.configuration({
  python_path: './out/python_app',
  framework_type: :fastapi,
  database_type: :sqlalchemy,
  api_features: {
    pagination: true,
    sorting: true,
    filtering: true
  },
  batch_jobs: [
    {name: 'process_data', description: 'Process data in background', processing_time: 5000}
  ]
})

# Apply configuration
generator.apply_configuration

# Set models
generator.models([user_model, post_model])

# Execute the generator
generator.execute
``` 