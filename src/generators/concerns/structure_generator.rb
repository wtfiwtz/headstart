module Tenant
  module StructureGenerator
    def create_directory_structure(db_type)
      # Create base directories
      directories = [
        "#{@express_path}/controllers",
        "#{@express_path}/models",
        "#{@express_path}/routes",
        "#{@express_path}/middleware",
        "#{@express_path}/utils"
      ]
      
      # Create directories
      directories.each do |dir|
        FileUtils.mkdir_p(dir)
      end
      
      # Create .env file with database connection string
      env_content = get_database_env_content(db_type)
      env_content += "PORT=3000\n"
      File.write("#{@express_path}/.env", env_content)
      
      # Create README.md
      readme_content = "# Express Application\n\n"
      readme_content += "This is an Express.js application generated by Dwelling.\n\n"
      readme_content += get_database_readme_content(db_type)
      readme_content += "## Getting Started\n\n"
      readme_content += "1. Install dependencies: `npm install`\n"
      readme_content += "2. Start the server: `npm start` or `npm run dev` for development\n"
      readme_content += get_database_setup_steps(db_type)
      
      File.write("#{@express_path}/README.md", readme_content)
      
      # Create .gitignore
      gitignore_content = <<~GITIGNORE
        node_modules/
        .env
        npm-debug.log
        yarn-error.log
        .DS_Store
      GITIGNORE
      
      File.write("#{@express_path}/.gitignore", gitignore_content)
    end
    
    def create_app_js(db_type)
      app_js_content = <<~JS
        require('dotenv').config();
        const express = require('express');
        const bodyParser = require('body-parser');
        const cors = require('cors');
        
        const app = express();
        
        // Middleware
        app.use(cors());
        app.use(bodyParser.json());
        app.use(bodyParser.urlencoded({ extended: true }));
        
        #{get_database_connection_code(db_type)}
        
        // Routes
        // Route imports will be added here during route generation
        
        // Default route
        app.get('/', (req, res) => {
          res.json({ message: 'Welcome to the Express API' });
        });
        
        // Start server
        const PORT = process.env.PORT || 3000;
        app.listen(PORT, () => {
          console.log(`Server is running on port ${PORT}`);
        });
      JS
      
      File.write("#{@express_path}/app.js", app_js_content)
    end
    
    def create_middleware_files
      # Create error handling middleware
      error_handler = <<~JS
        // Error handling middleware
        const errorHandler = (err, req, res, next) => {
          const statusCode = err.statusCode || 500;
          res.status(statusCode).json({
            status: 'error',
            statusCode,
            message: err.message,
            stack: process.env.NODE_ENV === 'production' ? '🥞' : err.stack
          });
        };
        
        module.exports = errorHandler;
      JS
      
      File.write("#{@express_path}/middleware/error_handler.js", error_handler)
      
      # Create authentication middleware template
      auth_middleware = <<~JS
        // Authentication middleware
        const authMiddleware = (req, res, next) => {
          // TODO: Implement authentication logic
          // This is a placeholder for authentication middleware
          next();
        };
        
        module.exports = authMiddleware;
      JS
      
      File.write("#{@express_path}/middleware/auth.js", auth_middleware)
    end
  end
end 