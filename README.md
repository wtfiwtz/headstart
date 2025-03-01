# Rails Application Generator

This generator creates Rails applications with predefined models, controllers, views, and routes based on YAML configuration files.

## Features

- Generate complete Rails applications with a single command
- Define models and their relationships in YAML
- Configure application settings in YAML
- Support for complex relationships (has_many_through, has_and_belongs_to_many)
- Automatic route generation
- Intelligent model generation with validations, scopes, and callbacks
- Plugin system for extending functionality
- WebAuthn/Passkeys support for passwordless authentication

## Installation

1. Clone this repository
2. Run `bundle install` to install dependencies

## Usage

```bash
bin/generate [options]
```

### Options

- `-c, --config FILE`: Path to configuration YAML file (default: `config/application.yml`)
- `-m, --models FILE`: Path to models YAML file (default: `config/models.yml`)
- `-h, --help`: Show help message

## Configuration Files

### Application Configuration (application.yml)

The application configuration file defines the overall settings for the generated Rails application:

```yaml
# Frontend framework (:mvc, :react, :vue)
frontend: mvc

# Database configuration (:sqlite, :postgresql, :mysql)
database: postgresql
database_options:
  pool: 5
  timeout: 5000
  username: postgres
  password: password

# Search engine (:elasticsearch, :meilisearch)
search_engine: elasticsearch
search_engine_options:
  host: http://localhost:9200
  index_prefix: myapp

# CSS framework (:bootstrap, :tailwind, :none)
css_framework: bootstrap

# Controller inheritance pattern (true/false)
controller_inheritance: true

# Form builder (:default, :simple_form, :formtastic)
form_builder: simple_form

# Gems to include
gems:
  - name: devise
    version: '~> 4.8'
  - name: pundit
    version: '~> 2.2'

# Monitoring tools (:new_relic, :datadog, :sentry)
monitoring:
  - new_relic
  - sentry

# Features to enable
features:
  # Authentication configuration
  authentication:
    provider: rodauth  # or devise
    generate_user: true
    passkeys: true  # Enable WebAuthn/passkeys support
    passkey_options:
      rp_name: "My Application"  # Relying Party name
      rp_id: "localhost"         # Relying Party ID (domain)
      origin: "http://localhost:3000"
    
  # File upload configuration
  file_upload:
    provider: active_storage
    
  # Background jobs configuration
  background_jobs:
    provider: sidekiq
    options:
      web_interface: true
```

### Models Configuration (models.yml)

The models configuration file defines the models and their relationships:

```yaml
models:
  # User model
  user:
    attributes:
      email: string
      name: string
      password_digest: string
    associations:
      - kind: has_many
        name: posts
        attrs:
          dependent: destroy
      - kind: has_one
        name: profile
        attrs:
          dependent: destroy

  # Profile model
  profile:
    attributes:
      bio: text
      avatar: string
    associations:
      - kind: belongs_to
        name: user
        attrs:
          optional: false
```

## Authentication with Passkeys (WebAuthn)

The generator supports modern passwordless authentication using WebAuthn/Passkeys with both Devise and Rodauth.

### Configuring Passkeys

To enable passkeys, add the following to your `application.yml`:

```yaml
features:
  authentication:
    provider: devise  # or rodauth
    passkeys: true
    passkey_options:
      rp_name: "My Application"  # The name shown during registration
      rp_id: "localhost"         # Your domain (use localhost for development)
      origin: "http://localhost:3000"  # Your application's origin
```

### Passkey Options

| Option | Description | Default |
|--------|-------------|---------|
| `rp_name` | The name of your application shown during WebAuthn registration | "Rails Application" |
| `rp_id` | The Relying Party ID (usually your domain) | "localhost" |
| `origin` | The origin of your application | "http://localhost:3000" |

### Supported Authentication Providers

- **Devise**: Uses the `devise-passkeys` gem for WebAuthn integration
- **Rodauth**: Uses Rodauth's built-in WebAuthn features

## API Features

All generated controllers include robust API endpoints with the following features:

### Pagination

The generator uses the Pagy gem for efficient pagination:

```
GET /users?page=2&per_page=20
```

Response includes pagination metadata:

```json
{
  "users": [...],
  "pagination": {
    "current_page": 2,
    "total_pages": 5,
    "total_count": 98,
    "per_page": 20
  }
}
```

### Sorting

Sort by any model attribute:

```
GET /users?sort=created_at&direction=desc
```

Multiple sort parameters are supported:

```
GET /users?q[s]=name+asc&q[s][]=email+desc
```

### Filtering

Basic filtering by exact match:

```
GET /users?email=user@example.com
```

Range filtering for numeric and date fields:

```
GET /users?created_at_from=2023-01-01&created_at_to=2023-12-31
GET /users?age_min=18&age_max=65
```

Text search across all string/text fields:

```
GET /users?q=search+term
```

Advanced filtering with Ransack:

```
GET /users?q[email_cont]=example.com&q[name_start]=John&q[created_at_gteq]=2023-01-01
```

Common Ransack predicates:
- `eq`: Equal
- `cont`: Contains
- `start`: Starts with
- `end`: Ends with
- `gt/lt`: Greater than/Less than
- `gteq/lteq`: Greater than or equal/Less than or equal

### Response Formats

All controllers support multiple response formats:

```
GET /users.json
GET /users.xml
GET /users.csv
```

### API Documentation

Each API endpoint includes metadata about available filters and sortable fields:

```json
{
  "users": [...],
  "pagination": {...},
  "meta": {
    "filters": {
      "email": {
        "predicates": ["eq", "cont", "start", "end"],
        "type": "string"
      },
      "age": {
        "predicates": ["eq", "gt", "lt", "gteq", "lteq"],
        "type": "integer"
      }
    },
    "sortable_fields": ["id", "email", "name", "created_at", "updated_at"]
  }
}
```

## Database Support

The generator supports multiple database systems:

### SQLite (Default)

Lightweight file-based database, perfect for development and small applications:

```yaml
database: sqlite
```

### PostgreSQL

Advanced SQL database with powerful features like JSON storage, full-text search, and more:

```yaml
database: postgresql
database_options:
  pool: 5
  username: postgres
  password: password
  host: localhost
  port: 5432
```

### MySQL

Popular SQL database with excellent performance:

```yaml
database: mysql
database_options:
  pool: 5
  username: root
  password: password
  host: localhost
  port: 3306
```

## Search Engine Integration

The generator supports advanced search capabilities through integration with popular search engines:

### Elasticsearch

Full-featured search engine with powerful text analysis, faceting, and more:

```yaml
search_engine: elasticsearch
search_engine_options:
  host: http://localhost:9200
  index_prefix: myapp
```

When Elasticsearch is enabled:
- All models include the `Searchable` concern
- Controllers gain a `/search` endpoint with highlighting
- Intelligent field mapping based on attribute types
- Support for pagination and sorting in search results

### MeiliSearch

Fast, lightweight search engine with typo tolerance and great developer experience:

```yaml
search_engine: meilisearch
search_engine_options:
  host: http://localhost:7700
  api_key: your_api_key
```

When MeiliSearch is enabled:
- All models include the `Searchable` concern with Searchkick integration
- Controllers gain a `/search` endpoint with highlighting
- Intelligent field mapping for prefix and infix search
- Support for pagination and sorting in search results

### Search API Endpoints

All controllers include a search endpoint:

```
GET /users/search?q=search+term&page=1&per_page=20&sort=name:asc
```

Response includes search results with highlights:

```json
{
  "users": [...],
  "highlights": {
    "1": {"name": ["John <em>Smith</em>"]},
    "2": {"bio": ["Works at <em>Smith</em> Industries"]}
  },
  "pagination": {
    "current_page": 1,
    "total_pages": 5,
    "total_count": 98,
    "per_page": 20
  }
}
```

## Supported Relationship Types

- `has_one`
- `has_many`
- `belongs_to`
- `has_and_belongs_to_many`
- `has_many_through` (via the `through` attribute)

## Association Options

The generator supports various ActiveRecord association options:

- `dependent`: `:destroy`, `:delete`, `:nullify`, etc.
- `class_name`: Custom class name
- `foreign_key`: Custom foreign key
- `through`: For has_many :through relationships
- `source`: For has_many :through relationships
- `polymorphic`: For polymorphic associations
- `counter_cache`: For counter cache columns
- `optional`: For optional belongs_to associations

## Examples

### Basic Usage

```bash
bin/generate
```

This will use the default configuration files (`config/application.yml` and `config/models.yml`).

### Custom Configuration Files

```bash
bin/generate --config my_config.yml --models my_models.yml
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a new Pull Request 