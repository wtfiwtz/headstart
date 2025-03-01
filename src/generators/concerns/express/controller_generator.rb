module Tenant
  module ExpressControllerGenerator
    def generate_controllers
      @models.each do |model|
        generate_controller(model)
      end
    end

    def generate_controller(model)
      model_name = model['name']
      
      # Determine file extension and path based on language
      file_ext = @language.to_s.downcase == "typescript" ? "ts" : "js"
      controller_path = @language.to_s.downcase == "typescript" ? "#{@express_path}/src/controllers" : "#{@express_path}/controllers"
      
      controller_file = "#{controller_path}/#{model_name.downcase}_controller.#{file_ext}"
      
      if @language.to_s.downcase == "typescript"
        controller_content = generate_typescript_controller(model_name)
      else
        controller_content = generate_javascript_controller(model_name)
      end
      
      File.write(controller_file, controller_content)
    end

    private

    def generate_typescript_controller(model_name)
      model_var = model_name.downcase
      model_import_path = "../models/#{model_var}"
      
      case @database_type.to_s.downcase
      when 'sequelize', 'sql', 'mysql', 'postgres', 'postgresql'
        <<~TS
          import { Request, Response, NextFunction } from 'express';
          import #{model_name} from '#{model_import_path}';

          // Get all #{model_name}s
          export const getAll#{model_name}s = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
            try {
              const #{model_var}s = await #{model_name}.findAll();
              res.status(200).json(#{model_var}s);
            } catch (error) {
              next(error);
            }
          };

          // Get a single #{model_name} by ID
          export const get#{model_name}ById = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
            try {
              const id = parseInt(req.params.id, 10);
              const #{model_var} = await #{model_name}.findByPk(id);
              
              if (!#{model_var}) {
                res.status(404).json({ message: '#{model_name} not found' });
                return;
              }
              
              res.status(200).json(#{model_var});
            } catch (error) {
              next(error);
            }
          };

          // Create a new #{model_name}
          export const create#{model_name} = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
            try {
              const new#{model_name} = await #{model_name}.create(req.body);
              res.status(201).json(new#{model_name});
            } catch (error) {
              next(error);
            }
          };

          // Update a #{model_name}
          export const update#{model_name} = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
            try {
              const id = parseInt(req.params.id, 10);
              const [updated] = await #{model_name}.update(req.body, {
                where: { id }
              });
              
              if (updated === 0) {
                res.status(404).json({ message: '#{model_name} not found' });
                return;
              }
              
              const updated#{model_name} = await #{model_name}.findByPk(id);
              res.status(200).json(updated#{model_name});
            } catch (error) {
              next(error);
            }
          };

          // Delete a #{model_name}
          export const delete#{model_name} = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
            try {
              const id = parseInt(req.params.id, 10);
              const deleted = await #{model_name}.destroy({
                where: { id }
              });
              
              if (deleted === 0) {
                res.status(404).json({ message: '#{model_name} not found' });
                return;
              }
              
              res.status(204).end();
            } catch (error) {
              next(error);
            }
          };
        TS
      when 'prisma'
        <<~TS
          import { Request, Response, NextFunction } from 'express';
          import { PrismaClient } from '@prisma/client';

          const prisma = new PrismaClient();

          // Get all #{model_name}s
          export const getAll#{model_name}s = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
            try {
              const #{model_var}s = await prisma.#{model_var}.findMany();
              res.status(200).json(#{model_var}s);
            } catch (error) {
              next(error);
            }
          };

          // Get a single #{model_name} by ID
          export const get#{model_name}ById = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
            try {
              const id = parseInt(req.params.id, 10);
              const #{model_var} = await prisma.#{model_var}.findUnique({
                where: { id }
              });
              
              if (!#{model_var}) {
                res.status(404).json({ message: '#{model_name} not found' });
                return;
              }
              
              res.status(200).json(#{model_var});
            } catch (error) {
              next(error);
            }
          };

          // Create a new #{model_name}
          export const create#{model_name} = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
            try {
              const new#{model_name} = await prisma.#{model_var}.create({
                data: req.body
              });
              res.status(201).json(new#{model_name});
            } catch (error) {
              next(error);
            }
          };

          // Update a #{model_name}
          export const update#{model_name} = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
            try {
              const id = parseInt(req.params.id, 10);
              const updated#{model_name} = await prisma.#{model_var}.update({
                where: { id },
                data: req.body
              });
              
              res.status(200).json(updated#{model_name});
            } catch (error) {
              if (error.code === 'P2025') {
                res.status(404).json({ message: '#{model_name} not found' });
                return;
              }
              next(error);
            }
          };

          // Delete a #{model_name}
          export const delete#{model_name} = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
            try {
              const id = parseInt(req.params.id, 10);
              await prisma.#{model_var}.delete({
                where: { id }
              });
              
              res.status(204).end();
            } catch (error) {
              if (error.code === 'P2025') {
                res.status(404).json({ message: '#{model_name} not found' });
                return;
              }
              next(error);
            }
          };
        TS
      else # Default to MongoDB
        <<~TS
          import { Request, Response, NextFunction } from 'express';
          import #{model_name} from '#{model_import_path}';

          // Get all #{model_name}s
          export const getAll#{model_name}s = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
            try {
              const #{model_var}s = await #{model_name}.find();
              res.status(200).json(#{model_var}s);
            } catch (error) {
              next(error);
            }
          };

          // Get a single #{model_name} by ID
          export const get#{model_name}ById = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
            try {
              const #{model_var} = await #{model_name}.findById(req.params.id);
              
              if (!#{model_var}) {
                res.status(404).json({ message: '#{model_name} not found' });
                return;
              }
              
              res.status(200).json(#{model_var});
            } catch (error) {
              next(error);
            }
          };

          // Create a new #{model_name}
          export const create#{model_name} = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
            try {
              const new#{model_name} = new #{model_name}(req.body);
              const saved#{model_name} = await new#{model_name}.save();
              res.status(201).json(saved#{model_name});
            } catch (error) {
              next(error);
            }
          };

          // Update a #{model_name}
          export const update#{model_name} = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
            try {
              const updated#{model_name} = await #{model_name}.findByIdAndUpdate(
                req.params.id,
                req.body,
                { new: true, runValidators: true }
              );
              
              if (!updated#{model_name}) {
                res.status(404).json({ message: '#{model_name} not found' });
                return;
              }
              
              res.status(200).json(updated#{model_name});
            } catch (error) {
              next(error);
            }
          };

          // Delete a #{model_name}
          export const delete#{model_name} = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
            try {
              const deleted#{model_name} = await #{model_name}.findByIdAndDelete(req.params.id);
              
              if (!deleted#{model_name}) {
                res.status(404).json({ message: '#{model_name} not found' });
                return;
              }
              
              res.status(204).end();
            } catch (error) {
              next(error);
            }
          };
        TS
      end
    end

    def generate_javascript_controller(model_name)
      model_var = model_name.downcase
      model_import_path = "../models/#{model_var}"
      
      case @database_type.to_s.downcase
      when 'sequelize', 'sql', 'mysql', 'postgres', 'postgresql'
        <<~JS
          const #{model_name} = require('#{model_import_path}');

          // Get all #{model_name}s
          exports.getAll#{model_name}s = async (req, res, next) => {
            try {
              const #{model_var}s = await #{model_name}.findAll();
              res.status(200).json(#{model_var}s);
            } catch (error) {
              next(error);
            }
          };

          // Get a single #{model_name} by ID
          exports.get#{model_name}ById = async (req, res, next) => {
            try {
              const id = parseInt(req.params.id, 10);
              const #{model_var} = await #{model_name}.findByPk(id);
              
              if (!#{model_var}) {
                return res.status(404).json({ message: '#{model_name} not found' });
              }
              
              res.status(200).json(#{model_var});
            } catch (error) {
              next(error);
            }
          };

          // Create a new #{model_name}
          exports.create#{model_name} = async (req, res, next) => {
            try {
              const new#{model_name} = await #{model_name}.create(req.body);
              res.status(201).json(new#{model_name});
            } catch (error) {
              next(error);
            }
          };

          // Update a #{model_name}
          exports.update#{model_name} = async (req, res, next) => {
            try {
              const id = parseInt(req.params.id, 10);
              const [updated] = await #{model_name}.update(req.body, {
                where: { id }
              });
              
              if (updated === 0) {
                return res.status(404).json({ message: '#{model_name} not found' });
              }
              
              const updated#{model_name} = await #{model_name}.findByPk(id);
              res.status(200).json(updated#{model_name});
            } catch (error) {
              next(error);
            }
          };

          // Delete a #{model_name}
          exports.delete#{model_name} = async (req, res, next) => {
            try {
              const id = parseInt(req.params.id, 10);
              const deleted = await #{model_name}.destroy({
                where: { id }
              });
              
              if (deleted === 0) {
                return res.status(404).json({ message: '#{model_name} not found' });
              }
              
              res.status(204).end();
            } catch (error) {
              next(error);
            }
          };
        JS
      when 'prisma'
        <<~JS
          const { PrismaClient } = require('@prisma/client');
          const prisma = new PrismaClient();

          // Get all #{model_name}s
          exports.getAll#{model_name}s = async (req, res, next) => {
            try {
              const #{model_var}s = await prisma.#{model_var}.findMany();
              res.status(200).json(#{model_var}s);
            } catch (error) {
              next(error);
            }
          };

          // Get a single #{model_name} by ID
          exports.get#{model_name}ById = async (req, res, next) => {
            try {
              const id = parseInt(req.params.id, 10);
              const #{model_var} = await prisma.#{model_var}.findUnique({
                where: { id }
              });
              
              if (!#{model_var}) {
                return res.status(404).json({ message: '#{model_name} not found' });
              }
              
              res.status(200).json(#{model_var});
            } catch (error) {
              next(error);
            }
          };

          // Create a new #{model_name}
          exports.create#{model_name} = async (req, res, next) => {
            try {
              const new#{model_name} = await prisma.#{model_var}.create({
                data: req.body
              });
              res.status(201).json(new#{model_name});
            } catch (error) {
              next(error);
            }
          };

          // Update a #{model_name}
          exports.update#{model_name} = async (req, res, next) => {
            try {
              const id = parseInt(req.params.id, 10);
              const updated#{model_name} = await prisma.#{model_var}.update({
                where: { id },
                data: req.body
              });
              
              res.status(200).json(updated#{model_name});
            } catch (error) {
              if (error.code === 'P2025') {
                return res.status(404).json({ message: '#{model_name} not found' });
              }
              next(error);
            }
          };

          // Delete a #{model_name}
          exports.delete#{model_name} = async (req, res, next) => {
            try {
              const id = parseInt(req.params.id, 10);
              await prisma.#{model_var}.delete({
                where: { id }
              });
              
              res.status(204).end();
            } catch (error) {
              if (error.code === 'P2025') {
                return res.status(404).json({ message: '#{model_name} not found' });
              }
              next(error);
            }
          };
        JS
      else # Default to MongoDB
        <<~JS
          const #{model_name} = require('#{model_import_path}');

          // Get all #{model_name}s
          exports.getAll#{model_name}s = async (req, res, next) => {
            try {
              const #{model_var}s = await #{model_name}.find();
              res.status(200).json(#{model_var}s);
            } catch (error) {
              next(error);
            }
          };

          // Get a single #{model_name} by ID
          exports.get#{model_name}ById = async (req, res, next) => {
            try {
              const #{model_var} = await #{model_name}.findById(req.params.id);
              
              if (!#{model_var}) {
                return res.status(404).json({ message: '#{model_name} not found' });
              }
              
              res.status(200).json(#{model_var});
            } catch (error) {
              next(error);
            }
          };

          // Create a new #{model_name}
          exports.create#{model_name} = async (req, res, next) => {
            try {
              const new#{model_name} = new #{model_name}(req.body);
              const saved#{model_name} = await new#{model_name}.save();
              res.status(201).json(saved#{model_name});
            } catch (error) {
              next(error);
            }
          };

          // Update a #{model_name}
          exports.update#{model_name} = async (req, res, next) => {
            try {
              const updated#{model_name} = await #{model_name}.findByIdAndUpdate(
                req.params.id,
                req.body,
                { new: true, runValidators: true }
              );
              
              if (!updated#{model_name}) {
                return res.status(404).json({ message: '#{model_name} not found' });
              }
              
              res.status(200).json(updated#{model_name});
            } catch (error) {
              next(error);
            }
          };

          // Delete a #{model_name}
          exports.delete#{model_name} = async (req, res, next) => {
            try {
              const deleted#{model_name} = await #{model_name}.findByIdAndDelete(req.params.id);
              
              if (!deleted#{model_name}) {
                return res.status(404).json({ message: '#{model_name} not found' });
              }
              
              res.status(204).end();
            } catch (error) {
              next(error);
            }
          };
        JS
      end
    end
  end
end 