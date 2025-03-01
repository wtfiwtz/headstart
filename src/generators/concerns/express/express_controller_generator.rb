module Tenant
  module ExpressControllerGenerator
    def generate_controllers
      log_info("Generating controllers for #{@models.length} models")
      
      @models.each do |model|
        generate_controller(model)
      end
    end
    
    def generate_controller(model)
      log_info("Generating controller for #{model.name}")
      
      # Determine which database to use based on configuration
      db_type = @configuration&.database_type || 'mongodb'
      
      case db_type.to_s.downcase
      when 'sequelize', 'sql', 'mysql', 'postgres', 'postgresql'
        generate_sequelize_controller(model)
      when 'prisma'
        generate_prisma_controller(model)
      else # Default to MongoDB
        generate_mongoose_controller(model)
      end
    end
    
    private
    
    def generate_mongoose_controller(model)
      controller_content = <<~JS
        const #{model.name.camelize} = require('../models/#{model.name.underscore}');

        // Get all #{model.name.pluralize}
        exports.get#{model.name.pluralize.camelize} = async (req, res) => {
          try {
            const #{model.name.underscore.pluralize} = await #{model.name.camelize}.find();
            res.status(200).json(#{model.name.underscore.pluralize});
          } catch (error) {
            res.status(500).json({ message: error.message });
          }
        };

        // Get a single #{model.name}
        exports.get#{model.name.camelize} = async (req, res) => {
          try {
            const #{model.name.underscore} = await #{model.name.camelize}.findById(req.params.id);
            if (!#{model.name.underscore}) {
              return res.status(404).json({ message: '#{model.name} not found' });
            }
            res.status(200).json(#{model.name.underscore});
          } catch (error) {
            res.status(500).json({ message: error.message });
          }
        };

        // Create a new #{model.name}
        exports.create#{model.name.camelize} = async (req, res) => {
          try {
            const #{model.name.underscore} = new #{model.name.camelize}(req.body);
            const new#{model.name.camelize} = await #{model.name.underscore}.save();
            res.status(201).json(new#{model.name.camelize});
          } catch (error) {
            res.status(400).json({ message: error.message });
          }
        };

        // Update a #{model.name}
        exports.update#{model.name.camelize} = async (req, res) => {
          try {
            const updated#{model.name.camelize} = await #{model.name.camelize}.findByIdAndUpdate(
              req.params.id,
              req.body,
              { new: true }
            );
            if (!updated#{model.name.camelize}) {
              return res.status(404).json({ message: '#{model.name} not found' });
            }
            res.status(200).json(updated#{model.name.camelize});
          } catch (error) {
            res.status(400).json({ message: error.message });
          }
        };

        // Delete a #{model.name}
        exports.delete#{model.name.camelize} = async (req, res) => {
          try {
            const #{model.name.underscore} = await #{model.name.camelize}.findByIdAndDelete(req.params.id);
            if (!#{model.name.underscore}) {
              return res.status(404).json({ message: '#{model.name} not found' });
            }
            res.status(200).json({ message: '#{model.name} deleted successfully' });
          } catch (error) {
            res.status(500).json({ message: error.message });
          }
        };
      JS
      
      File.write("#{@express_path}/controllers/#{model.name.underscore}_controller.js", controller_content)
    end
    
    def generate_sequelize_controller(model)
      controller_content = <<~JS
        const #{model.name.camelize} = require('../models/#{model.name.underscore}');

        // Get all #{model.name.pluralize}
        exports.get#{model.name.pluralize.camelize} = async (req, res) => {
          try {
            const #{model.name.underscore.pluralize} = await #{model.name.camelize}.findAll();
            res.status(200).json(#{model.name.underscore.pluralize});
          } catch (error) {
            res.status(500).json({ message: error.message });
          }
        };

        // Get a single #{model.name}
        exports.get#{model.name.camelize} = async (req, res) => {
          try {
            const #{model.name.underscore} = await #{model.name.camelize}.findByPk(req.params.id);
            if (!#{model.name.underscore}) {
              return res.status(404).json({ message: '#{model.name} not found' });
            }
            res.status(200).json(#{model.name.underscore});
          } catch (error) {
            res.status(500).json({ message: error.message });
          }
        };

        // Create a new #{model.name}
        exports.create#{model.name.camelize} = async (req, res) => {
          try {
            const new#{model.name.camelize} = await #{model.name.camelize}.create(req.body);
            res.status(201).json(new#{model.name.camelize});
          } catch (error) {
            res.status(400).json({ message: error.message });
          }
        };

        // Update a #{model.name}
        exports.update#{model.name.camelize} = async (req, res) => {
          try {
            const [updated] = await #{model.name.camelize}.update(req.body, {
              where: { id: req.params.id }
            });
            
            if (updated) {
              const updated#{model.name.camelize} = await #{model.name.camelize}.findByPk(req.params.id);
              res.status(200).json(updated#{model.name.camelize});
            } else {
              return res.status(404).json({ message: '#{model.name} not found' });
            }
          } catch (error) {
            res.status(400).json({ message: error.message });
          }
        };

        // Delete a #{model.name}
        exports.delete#{model.name.camelize} = async (req, res) => {
          try {
            const deleted = await #{model.name.camelize}.destroy({
              where: { id: req.params.id }
            });
            
            if (deleted) {
              res.status(200).json({ message: '#{model.name} deleted successfully' });
            } else {
              return res.status(404).json({ message: '#{model.name} not found' });
            }
          } catch (error) {
            res.status(500).json({ message: error.message });
          }
        };
      JS
      
      File.write("#{@express_path}/controllers/#{model.name.underscore}_controller.js", controller_content)
    end
    
    def generate_prisma_controller(model)
      controller_content = <<~JS
        // Get all #{model.name.pluralize}
        exports.get#{model.name.pluralize.camelize} = async (req, res) => {
          try {
            const #{model.name.underscore.pluralize} = await prisma.#{model.name.camelize}.findMany();
            res.status(200).json(#{model.name.underscore.pluralize});
          } catch (error) {
            res.status(500).json({ message: error.message });
          }
        };

        // Get a single #{model.name}
        exports.get#{model.name.camelize} = async (req, res) => {
          try {
            const #{model.name.underscore} = await prisma.#{model.name.camelize}.findUnique({
              where: { id: parseInt(req.params.id) }
            });
            
            if (!#{model.name.underscore}) {
              return res.status(404).json({ message: '#{model.name} not found' });
            }
            
            res.status(200).json(#{model.name.underscore});
          } catch (error) {
            res.status(500).json({ message: error.message });
          }
        };

        // Create a new #{model.name}
        exports.create#{model.name.camelize} = async (req, res) => {
          try {
            const new#{model.name.camelize} = await prisma.#{model.name.camelize}.create({
              data: req.body
            });
            
            res.status(201).json(new#{model.name.camelize});
          } catch (error) {
            res.status(400).json({ message: error.message });
          }
        };

        // Update a #{model.name}
        exports.update#{model.name.camelize} = async (req, res) => {
          try {
            const updated#{model.name.camelize} = await prisma.#{model.name.camelize}.update({
              where: { id: parseInt(req.params.id) },
              data: req.body
            });
            
            res.status(200).json(updated#{model.name.camelize});
          } catch (error) {
            if (error.code === 'P2025') {
              return res.status(404).json({ message: '#{model.name} not found' });
            }
            res.status(400).json({ message: error.message });
          }
        };

        // Delete a #{model.name}
        exports.delete#{model.name.camelize} = async (req, res) => {
          try {
            await prisma.#{model.name.camelize}.delete({
              where: { id: parseInt(req.params.id) }
            });
            
            res.status(200).json({ message: '#{model.name} deleted successfully' });
          } catch (error) {
            if (error.code === 'P2025') {
              return res.status(404).json({ message: '#{model.name} not found' });
            }
            res.status(500).json({ message: error.message });
          }
        };
      JS
      
      File.write("#{@express_path}/controllers/#{model.name.underscore}_controller.js", controller_content)
    end
  end
end 