# Dwelling Model Builder

This tool allows you to generate Ruby on Rails or Express.js applications from YAML model definitions.

## Features

- Define models, attributes, and associations in YAML files
- Generate Ruby on Rails applications with configurable options:
  - Template engines (ERB, SLIM, HAML)
  - Form builders (Default, Simple Form, Formtastic)
  - CSS frameworks (Bootstrap, Tailwind)
  - Authentication, file uploads, and more
- Generate Express.js applications with configurable options:
  - Database types (MongoDB, Sequelize, Prisma)
  - Model and controller generation
  - API routes
  - Advanced API features (pagination, sorting, filtering)

## Usage

### Command Line

```bash
# Generate using separate configuration and models files
bin/generate --config config/application.yml --models config/models.yml

# Generate using a combined configuration and models file
bin/generate --file models.yml

# Specify generator type (ruby or express)
bin/generate --file models.yml --generator express

# Show help
bin/generate --help
```

### Programmatically

```ruby
# Generate from YAML file
Tenant::Builder.build_from_yaml('models.yml', :ruby)

# Or use the DSL for more control
Tenant::Builder.configure do |config|
  config.template_engine = :slim
  # ... other configuration options
end

# Define models
user = Tenant::Builder.model(:user) do |b, m|
  b.attributes m, { name: :string, email: :string }
  b.has_many m, :posts
end

# Generate the application
Tenant::Builder.generator(:ruby)
  .models([user])
  .execute
```

## YAML File Structure

You can use either separate files for configuration and models, or a combined file.

### Combined File Structure

```yaml
# Application Configuration
frontend: mvc  # mvc, react, vue
css_framework: bootstrap  # bootstrap, tailwind, bulma
form_builder: simple_form  # simple_form, formtastic, default
template_engine: slim  # erb, slim, haml

# Gems for Ruby/Rails
gems:
  - name: rodauth-rails
  - name: image_processing
    version: '~> 1.2'

# Express.js specific configuration
express_path: './out/express_app'
database_type: mongodb  # mongodb, sequelize, prisma

# Model definitions
models:
  user:
    attributes:
      name: string
      email: string
    associations:
      - kind: has_many
        name: posts
        attrs:
          dependent: destroy

  post:
    attributes:
      title: string
      content: text
    associations:
      - kind: belongs_to
        name: user
```

### Separate Files

#### Configuration File (application.yml)

```yaml
frontend: mvc
css_framework: bootstrap
form_builder: simple_form
template_engine: slim
gems:
  - name: rodauth-rails
  - name: image_processing
    version: '~> 1.2'
features:
  authentication:
    provider: rodauth
```

#### Models File (models.yml)

```yaml
user:
  attributes:
    name: string
    email: string
  associations:
    - kind: has_many
      name: posts
      attrs:
        dependent: destroy

post:
  attributes:
    title: string
    content: text
  associations:
    - kind: belongs_to
      name: user
```

## Express.js API Features

The Express.js generator includes advanced API features for building robust RESTful APIs:

### Pagination

Automatically adds pagination to your API endpoints:

```
GET /api/users?page=2&limit=10
```

Response includes pagination metadata:

```json
{
  "data": [...],
  "pagination": {
    "total": 100,
    "totalPages": 10,
    "currentPage": 2,
    "limit": 10,
    "hasNextPage": true,
    "hasPrevPage": true,
    "nextPage": 3,
    "prevPage": 1
  }
}
```

### Sorting

Sort results by any field in ascending or descending order:

```
GET /api/users?sort=name:asc,createdAt:desc
```

### Filtering

Filter results using simple key-value pairs:

```
GET /api/users?filter=status:active,role:admin
```

Or use advanced operators:

```
GET /api/users?filter=age:gt:18,name:regex:john
```

Supported operators:
- `gt:` - Greater than
- `lt:` - Less than
- `gte:` - Greater than or equal to
- `lte:` - Less than or equal to
- `ne:` - Not equal to
- `regex:` - Regular expression (case insensitive)

### Field Selection

Select only the fields you need:

```
GET /api/users?fields=name,email,role
```

## Supported Association Types

- `has_one`
- `has_many`
- `belongs_to`
- `has_and_belongs_to_many`
- `has_many` with `through` (for Rails)

## Supported Attribute Types

For Rails:
- `string`
- `text`
- `integer`
- `float`
- `decimal`
- `datetime`
- `date`
- `time`
- `boolean`
- `binary`
- `json`

For Express/MongoDB:
- `String`
- `Number`
- `Date`
- `Boolean`
- `ObjectId`
- `Array`
- `Object`

For Express/Sequelize:
- `STRING`
- `TEXT`
- `INTEGER`
- `FLOAT`
- `DECIMAL`
- `DATE`
- `BOOLEAN`
- `JSON`

## License

MIT 