# Express.js Generator Concerns

This directory contains the concerns (modules) used specifically by the Express.js generator. Each concern is responsible for a specific aspect of the Express.js application generation process.

## Structure

The Express.js generator has been refactored into separate concerns to improve maintainability and organization. Each concern is responsible for a specific aspect of the Express.js application generation process.

### Concerns

- **ExpressConfigurationHandler**: Handles Express-specific configuration settings and validation.
- **ExpressPackageManager**: Manages npm package dependencies and installation for Express applications.
- **ExpressDatabaseHandler**: Handles database-specific configurations and setup for Express applications.
- **ExpressStructureGenerator**: Creates the directory structure and basic files for Express applications.
- **ExpressTemplateHandler**: Generates utility files and templates for Express applications.
- **ExpressModelGenerator**: Generates models for different database types (MongoDB, Sequelize, Prisma).
- **ExpressControllerGenerator**: Generates controllers for different database types.
- **ExpressRouteGenerator**: Generates routes for different models.

## Supported Database Types

The Express.js generator supports the following database types:

- **MongoDB**: Uses Mongoose ODM.
- **Sequelize**: Uses Sequelize ORM with PostgreSQL or MySQL.
- **Prisma**: Uses Prisma ORM with PostgreSQL.

## Adding New Features

To add new features to the Express.js generator, you can create a new concern or extend an existing one. Each concern should be a module that can be included in the ExpressGenerator class.

For example, to add support for a new database type, you would need to:

1. Update the `ExpressDatabaseHandler` concern to support the new database type.
2. Update the `ExpressModelGenerator` concern to generate models for the new database type.
3. Update the `ExpressControllerGenerator` concern to generate controllers for the new database type.
4. Update the `ExpressPackageManager` concern to include the necessary dependencies for the new database type.

## Usage

These concerns are used by the ExpressGenerator class to generate a complete Express.js application. The generator is initialized with a configuration object that specifies the database type, models, and other settings.

```ruby
generator = Tenant::Frameworks::Node::ExpressGenerator.new
generator.apply_configuration({
  express_path: "path/to/express/app",
  database_type: "mongodb", # or "sequelize", "prisma"
  models: [
    {
      name: "User",
      attributes: [
        { name: "name", type: "string" },
        { name: "email", type: "string" },
        { name: "password", type: "string" }
      ]
    }
  ]
})
generator.execute
``` 