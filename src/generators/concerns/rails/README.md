# Rails Generator Concerns

This directory contains the concerns (modules) used specifically by the Rails generator. Each concern is responsible for a specific aspect of the Rails application generation process.

## Structure

The Rails generator has been refactored into separate concerns to improve maintainability and organization. Each concern is responsible for a specific aspect of the Rails application generation process.

### Concerns

- **ModelGenerator**: Handles model generation for Rails applications.
- **ControllerGenerator**: Handles controller generation for Rails applications.
- **ViewGenerator**: Handles view generation for Rails applications.
- **RouteGenerator**: Handles route generation for Rails applications.
- **AssociationHandler**: Handles association generation for Rails models.
- **ConfigurationHandler**: Handles Rails-specific configuration settings and validation.
- **TemplateHandler**: Generates templates for Rails applications.
- **VectorDatabaseHandler**: Handles vector database integration for Rails applications.

## Supported Features

The Rails generator supports the following features:

- **Models**: Generates models with attributes, validations, and associations.
- **Controllers**: Generates controllers with CRUD actions.
- **Views**: Generates views for CRUD actions.
- **Routes**: Generates routes for controllers.
- **Associations**: Generates associations between models.
- **Vector Databases**: Integrates with vector databases for search functionality.

## Adding New Features

To add new features to the Rails generator, you can create a new concern or extend an existing one. Each concern should be a module that can be included in the RailsGenerator class.

For example, to add support for a new feature, you would need to:

1. Create a new concern file or update an existing one.
2. Implement the necessary methods to support the feature.
3. Include the concern in the RailsGenerator class.

## Usage

These concerns are used by the RailsGenerator class to generate a complete Rails application. The generator is initialized with a configuration object that specifies the necessary settings.

```ruby
generator = Tenant::Frameworks::Ruby::RailsGenerator.new
generator.apply_configuration({
  rails_path: "path/to/rails/app",
  database_type: "postgresql",
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