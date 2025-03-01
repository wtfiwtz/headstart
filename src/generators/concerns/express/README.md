# Express.js Generator Concerns

This directory contains concerns (modules) specifically for the Express.js generator. Each concern is responsible for a specific aspect of the application generation process.

## Structure

The Express.js generator has been refactored into separate concerns to improve maintainability and organization. Each concern focuses on a specific responsibility, making the code more modular and easier to extend.

## Concerns

- **ExpressConfigurationHandler**: Manages configuration settings and validation for Express.js applications.
- **ExpressPackageManager**: Handles npm package dependencies and installation.
- **ExpressDatabaseHandler**: Manages database configurations and setup for MongoDB, Sequelize, and Prisma.
- **ExpressStructureGenerator**: Creates the directory structure and basic files for an Express.js application.
- **ExpressTemplateHandler**: Generates utility files and templates for Express.js applications.
- **ExpressModelGenerator**: Generates models for MongoDB, Sequelize, and Prisma.
- **ExpressControllerGenerator**: Generates controllers for MongoDB, Sequelize, and Prisma.
- **ExpressRouteGenerator**: Generates routes for Express.js applications.
- **ExpressApiFeaturesHandler**: Adds advanced API features like pagination, sorting, and filtering to Express.js applications.

## Supported Database Types

- **MongoDB**: Uses Mongoose ODM for MongoDB integration.
- **Sequelize**: ORM for SQL databases (MySQL, PostgreSQL, SQLite, etc.).
- **Prisma**: Modern database toolkit for TypeScript and Node.js.

## API Features

The `ExpressApiFeaturesHandler` concern adds the following features to your Express.js API:

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

## Adding New Features

To add a new feature or extend an existing one:

1. Create a new concern or modify an existing one in this directory.
2. Include the concern in the `ExpressGenerator` class in `src/generators/frameworks/node/express_generator.rb`.
3. Update this README to document the new feature.

## Usage Example

```ruby
# Initialize the Express generator with a configuration
generator = Tenant::ExpressGenerator.new
generator.apply_configuration({
  express_path: './out/express_app',
  database_type: :mongodb,
  models: [...]
})
generator.execute
``` 