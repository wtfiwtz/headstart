module Tenant
  module ExpressRouteGenerator
    def generate_routes
      log_info("Generating routes for #{@models.length} models")
      
      # Generate individual route files
      @models.each do |model|
        generate_route(model)
      end
      
      # Update app.js to include routes
      update_app_js_with_routes
    end
    
    private
    
    def generate_route(model)
      log_info("Generating route for #{model.name}")
      
      route_content = <<~JS
        const express = require('express');
        const router = express.Router();
        const #{model.name.underscore}Controller = require('../controllers/#{model.name.underscore}_controller');

        // Get all #{model.name.pluralize}
        router.get('/', #{model.name.underscore}Controller.get#{model.name.pluralize.camelize});

        // Get a single #{model.name}
        router.get('/:id', #{model.name.underscore}Controller.get#{model.name.camelize});

        // Create a new #{model.name}
        router.post('/', #{model.name.underscore}Controller.create#{model.name.camelize});

        // Update a #{model.name}
        router.put('/:id', #{model.name.underscore}Controller.update#{model.name.camelize});

        // Delete a #{model.name}
        router.delete('/:id', #{model.name.underscore}Controller.delete#{model.name.camelize});

        module.exports = router;
      JS
      
      File.write("#{@express_path}/routes/#{model.name.underscore}_routes.js", route_content)
    end
    
    def update_app_js_with_routes
      # Read the existing app.js
      app_js_path = "#{@express_path}/app.js"
      app_js_content = File.read(app_js_path)
      
      # Generate route imports
      route_imports = @models.map do |model|
        "const #{model.name.underscore}Routes = require('./routes/#{model.name.underscore}_routes');"
      end.join("\n")
      
      # Generate route usage
      route_usage = @models.map do |model|
        "app.use('/api/#{model.name.underscore.pluralize}', #{model.name.underscore}Routes);"
      end.join("\n")
      
      # Insert route imports after the last require statement
      updated_content = app_js_content.gsub(/require\([^\)]+\);(?![\s\S]*require\([^\)]+\);)/, "\\0\n\n// Route imports\n#{route_imports}")
      
      # Insert route usage before the server start
      updated_content = updated_content.gsub(/app\.listen/, "// API Routes\n#{route_usage}\n\n// Start server\napp.listen")
      
      # Write the updated app.js
      File.write(app_js_path, updated_content)
    end
  end
end 