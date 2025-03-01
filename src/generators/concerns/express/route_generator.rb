module Tenant
  module ExpressRouteGenerator
    def generate_routes
      @models.each do |model|
        generate_route(model)
      end
      
      # Update app.js with route imports
      update_app_with_routes
    end

    def generate_route(model)
      model_name = model['name']
      model_var = model_name.downcase
      
      # Determine file extension and path based on language
      file_ext = @language.to_s.downcase == "typescript" ? "ts" : "js"
      route_path = @language.to_s.downcase == "typescript" ? "#{@express_path}/src/routes" : "#{@express_path}/routes"
      
      route_file = "#{route_path}/#{model_var}_routes.#{file_ext}"
      
      if @language.to_s.downcase == "typescript"
        route_content = <<~TS
          import express, { Router } from 'express';
          import * as #{model_var}Controller from '../controllers/#{model_var}_controller';

          const router: Router = express.Router();

          // GET all #{model_name}s
          router.get('/', #{model_var}Controller.getAll#{model_name}s);

          // GET a single #{model_name} by ID
          router.get('/:id', #{model_var}Controller.get#{model_name}ById);

          // POST a new #{model_name}
          router.post('/', #{model_var}Controller.create#{model_name});

          // PUT/update a #{model_name}
          router.put('/:id', #{model_var}Controller.update#{model_name});

          // DELETE a #{model_name}
          router.delete('/:id', #{model_var}Controller.delete#{model_name});

          export default router;
        TS
      else
        route_content = <<~JS
          const express = require('express');
          const router = express.Router();
          const #{model_var}Controller = require('../controllers/#{model_var}_controller');

          // GET all #{model_name}s
          router.get('/', #{model_var}Controller.getAll#{model_name}s);

          // GET a single #{model_name} by ID
          router.get('/:id', #{model_var}Controller.get#{model_name}ById);

          // POST a new #{model_name}
          router.post('/', #{model_var}Controller.create#{model_name});

          // PUT/update a #{model_name}
          router.put('/:id', #{model_var}Controller.update#{model_name});

          // DELETE a #{model_name}
          router.delete('/:id', #{model_var}Controller.delete#{model_name});

          module.exports = router;
        JS
      end
      
      File.write(route_file, route_content)
    end

    def update_app_with_routes
      # Determine file extension and path based on language
      file_ext = @language.to_s.downcase == "typescript" ? "ts" : "js"
      app_file = @language.to_s.downcase == "typescript" ? "#{@express_path}/src/app.#{file_ext}" : "#{@express_path}/app.#{file_ext}"
      
      # Read the current app.js content
      app_content = File.read(app_file)
      
      # Prepare route imports and usage
      route_imports = []
      route_usage = []
      
      @models.each do |model|
        model_var = model['name'].downcase
        
        if @language.to_s.downcase == "typescript"
          route_imports << "import #{model_var}Routes from './routes/#{model_var}_routes';"
          route_usage << "app.use('/api/#{model_var}s', #{model_var}Routes);"
        else
          route_imports << "const #{model_var}Routes = require('./routes/#{model_var}_routes');"
          route_usage << "app.use('/api/#{model_var}s', #{model_var}Routes);"
        end
      end
      
      # Find the position to insert route imports
      import_marker = @language.to_s.downcase == "typescript" ? 
        "import express" : 
        "const express = require('express')"
      
      import_position = app_content.index(import_marker)
      if import_position
        # Insert route imports after the last import statement
        last_import_end = app_content.rindex("\n", app_content.index("// Middleware"))
        app_content.insert(last_import_end, "\n// Route imports\n#{route_imports.join("\n")}\n")
      end
      
      # Find the position to insert route usage
      routes_marker = "// Routes"
      routes_position = app_content.index(routes_marker)
      if routes_position
        # Insert route usage after the Routes comment
        app_content.sub!("// Routes\n// Route imports will be added here during route generation", "// Routes\n#{route_usage.join("\n")}")
      end
      
      # Write the updated content back to app.js
      File.write(app_file, app_content)
    end
  end
end 