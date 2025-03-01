# Generator Concerns

This directory contains the concerns (modules) used by various generators in the Dwelling application. Each concern is responsible for a specific aspect of the generation process.

## Structure

The generators have been refactored into separate concerns to improve maintainability and organization. Each concern is responsible for a specific aspect of the generation process.

### Subdirectories

- **express/**: Contains concerns specific to the Express.js generator.
- **rails/**: Contains concerns specific to the Rails generator.
- **setup_commands/**: Contains concerns for setting up commands.
- **css_frameworks/**: Contains concerns for CSS frameworks.

### Common Concerns

- **logging.rb**: Provides logging functionality for all generators.

## Express.js Generator Concerns

The Express.js generator concerns are located in the `express/` subdirectory. These concerns handle various aspects of Express.js application generation, including:

- Configuration handling
- Package management
- Database handling
- Structure generation
- Template handling
- Model generation
- Controller generation
- Route generation

For more details, see the [Express.js Generator Concerns README](./express/README.md).

## Rails Generator Concerns

The Rails generator concerns are located in the `rails/` subdirectory. These concerns handle various aspects of Rails application generation, including:

- Model generation
- Controller generation
- View generation
- Route generation
- Association handling
- Configuration handling
- Template handling
- Vector database handling

For more details, see the [Rails Generator Concerns README](./rails/README.md).

## Adding New Generators

To add a new generator, create a new subdirectory in this directory and add the necessary concern files. Each concern should be a module that can be included in the generator class.

For example, to add a new generator for a different framework, you would:

1. Create a new subdirectory for the framework (e.g., `django/`).
2. Create concern files for various aspects of the framework.
3. Create a generator class that includes these concerns.

## Usage

These concerns are used by the generator classes to generate complete applications. Each generator is initialized with a configuration object that specifies the necessary settings.

```ruby
# Example for Express.js generator
generator = Tenant::Frameworks::Node::ExpressGenerator.new
generator.apply_configuration({
  express_path: "path/to/express/app",
  database_type: "mongodb",
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