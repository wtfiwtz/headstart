module Tenant
  module ExpressApiFeaturesHandler
    def generate_api_features
      log_info("Generating API features (pagination, sorting, filtering)")
      
      # Determine directory paths based on language
      base_path = @language.to_s.downcase == "typescript" ? "#{@express_path}/src" : @express_path
      
      # Create middleware directory if it doesn't exist
      middleware_dir = "#{base_path}/middleware"
      FileUtils.mkdir_p(middleware_dir)
      
      # Generate API features middleware
      generate_pagination_middleware(middleware_dir)
      generate_sorting_middleware(middleware_dir)
      generate_filtering_middleware(middleware_dir)
      
      # Create utils directory if it doesn't exist
      utils_dir = "#{base_path}/utils"
      FileUtils.mkdir_p(utils_dir)
      
      # Generate API features utilities
      generate_api_features_utils(utils_dir)
      
      # Update controller templates to use these features
      update_controller_templates
    end
    
    private
    
    def generate_pagination_middleware(dir)
      # Determine file extension based on language
      file_ext = @language.to_s.downcase == "typescript" ? "ts" : "js"
      pagination_file = "#{dir}/pagination.#{file_ext}"
      
      if @language.to_s.downcase == "typescript"
        pagination_content = <<~TYPESCRIPT
          /**
           * Pagination middleware for Express.js
           * Adds pagination functionality to API requests
           */
          
          import { Request, Response, NextFunction } from 'express';

          // Extend Express Request interface
          declare global {
            namespace Express {
              interface Request {
                pagination?: {
                  page: number;
                  limit: number;
                  skip: number;
                };
              }
              interface Response {
                paginate?: (data: any[], total: number) => {
                  data: any[];
                  pagination: {
                    total: number;
                    totalPages: number;
                    currentPage: number;
                    limit: number;
                    hasNextPage: boolean;
                    hasPrevPage: boolean;
                    nextPage: number | null;
                    prevPage: number | null;
                  };
                };
              }
            }
          }
          
          const pagination = (req: Request, res: Response, next: NextFunction): void => {
            // Default pagination values
            const page = parseInt(req.query.page as string, 10) || 1;
            const limit = parseInt(req.query.limit as string, 10) || 10;
            
            // Calculate skip value for database queries
            const skip = (page - 1) * limit;
            
            // Add pagination object to request
            req.pagination = {
              page,
              limit,
              skip
            };
            
            // Add pagination response helper to res object
            res.paginate = (data: any[], total: number) => {
              const totalPages = Math.ceil(total / limit);
              const hasNextPage = page < totalPages;
              const hasPrevPage = page > 1;
              
              return {
                data,
                pagination: {
                  total,
                  totalPages,
                  currentPage: page,
                  limit,
                  hasNextPage,
                  hasPrevPage,
                  nextPage: hasNextPage ? page + 1 : null,
                  prevPage: hasPrevPage ? page - 1 : null
                }
              };
            };
            
            next();
          };
          
          export default pagination;
        TYPESCRIPT
      else
        pagination_content = <<~JAVASCRIPT
          /**
           * Pagination middleware for Express.js
           * Adds pagination functionality to API requests
           */
          
          const pagination = (req, res, next) => {
            // Default pagination values
            const page = parseInt(req.query.page, 10) || 1;
            const limit = parseInt(req.query.limit, 10) || 10;
            
            // Calculate skip value for database queries
            const skip = (page - 1) * limit;
            
            // Add pagination object to request
            req.pagination = {
              page,
              limit,
              skip
            };
            
            // Add pagination response helper to res object
            res.paginate = (data, total) => {
              const totalPages = Math.ceil(total / limit);
              const hasNextPage = page < totalPages;
              const hasPrevPage = page > 1;
              
              return {
                data,
                pagination: {
                  total,
                  totalPages,
                  currentPage: page,
                  limit,
                  hasNextPage,
                  hasPrevPage,
                  nextPage: hasNextPage ? page + 1 : null,
                  prevPage: hasPrevPage ? page - 1 : null
                }
              };
            };
            
            next();
          };
          
          module.exports = pagination;
        JAVASCRIPT
      end
      
      File.write(pagination_file, pagination_content)
      log_info("Generated pagination middleware at #{pagination_file}")
    end
    
    def generate_sorting_middleware(dir)
      # Determine file extension based on language
      file_ext = @language.to_s.downcase == "typescript" ? "ts" : "js"
      sorting_file = "#{dir}/sorting.#{file_ext}"
      
      if @language.to_s.downcase == "typescript"
        sorting_content = <<~TYPESCRIPT
          /**
           * Sorting middleware for Express.js
           * Adds sorting functionality to API requests
           */
          
          import { Request, Response, NextFunction } from 'express';

          // Extend Express Request interface
          declare global {
            namespace Express {
              interface Request {
                sorting?: Record<string, 1 | -1>;
              }
            }
          }
          
          interface SortOptions {
            [key: string]: 1 | -1;
          }
          
          const sorting = (defaultSort: SortOptions = { createdAt: -1 }) => {
            return (req: Request, res: Response, next: NextFunction): void => {
              // Get sort parameter from query string
              const sort = req.query.sort as string;
              
              // Initialize sort object with default sort
              let sortObj: SortOptions = { ...defaultSort };
              
              if (sort) {
                // Parse sort parameter (format: field:direction,field:direction)
                // Example: name:asc,createdAt:desc
                const sortParams = sort.split(',');
                
                sortObj = {};
                
                sortParams.forEach(param => {
                  const [field, direction] = param.split(':');
                  
                  if (field && direction) {
                    // Convert direction to MongoDB format (1 for asc, -1 for desc)
                    sortObj[field] = direction.toLowerCase() === 'asc' ? 1 : -1;
                  }
                });
              }
              
              // Add sort object to request
              req.sorting = sortObj;
              
              next();
            };
          };
          
          export default sorting;
        TYPESCRIPT
      else
        sorting_content = <<~JAVASCRIPT
          /**
           * Sorting middleware for Express.js
           * Adds sorting functionality to API requests
           */
          
          const sorting = (defaultSort = { createdAt: -1 }) => {
            return (req, res, next) => {
              // Get sort parameter from query string
              const { sort } = req.query;
              
              // Initialize sort object with default sort
              let sortObj = { ...defaultSort };
              
              if (sort) {
                // Parse sort parameter (format: field:direction,field:direction)
                // Example: name:asc,createdAt:desc
                const sortParams = sort.split(',');
                
                sortObj = {};
                
                sortParams.forEach(param => {
                  const [field, direction] = param.split(':');
                  
                  if (field && direction) {
                    // Convert direction to MongoDB format (1 for asc, -1 for desc)
                    sortObj[field] = direction.toLowerCase() === 'asc' ? 1 : -1;
                  }
                });
              }
              
              // Add sort object to request
              req.sorting = sortObj;
              
              next();
            };
          };
          
          module.exports = sorting;
        JAVASCRIPT
      end
      
      File.write(sorting_file, sorting_content)
      log_info("Generated sorting middleware at #{sorting_file}")
    end
    
    def generate_filtering_middleware(dir)
      # Determine file extension based on language
      file_ext = @language.to_s.downcase == "typescript" ? "ts" : "js"
      filtering_file = "#{dir}/filtering.#{file_ext}"
      
      if @language.to_s.downcase == "typescript"
        filtering_content = <<~TYPESCRIPT
          /**
           * Filtering middleware for Express.js
           * Adds filtering functionality to API requests
           */
          
          import { Request, Response, NextFunction } from 'express';

          // Extend Express Request interface
          declare global {
            namespace Express {
              interface Request {
                filtering?: Record<string, any>;
              }
            }
          }
          
          const filtering = (allowedFields: string[] = []) => {
            return (req: Request, res: Response, next: NextFunction): void => {
              // Get filter parameters from query string
              const filter = req.query.filter as string;
              
              // Initialize filter object
              let filterObj: Record<string, any> = {};
              
              if (filter) {
                try {
                  // Try to parse JSON filter
                  const parsedFilter = JSON.parse(filter);
                  
                  // If allowedFields is provided, only include those fields
                  if (allowedFields.length > 0) {
                    Object.keys(parsedFilter).forEach(key => {
                      if (allowedFields.includes(key)) {
                        filterObj[key] = parsedFilter[key];
                      }
                    });
                  } else {
                    filterObj = parsedFilter;
                  }
                } catch (error) {
                  // If JSON parsing fails, try to parse as simple key-value pairs
                  // Format: key1:value1,key2:value2
                  const filterParams = filter.split(',');
                  
                  filterParams.forEach(param => {
                    const [key, value] = param.split(':');
                    
                    if (key && value && (allowedFields.length === 0 || allowedFields.includes(key))) {
                      // Handle special operators
                      if (value.startsWith('gt:')) {
                        filterObj[key] = { $gt: value.substring(3) };
                      } else if (value.startsWith('lt:')) {
                        filterObj[key] = { $lt: value.substring(3) };
                      } else if (value.startsWith('gte:')) {
                        filterObj[key] = { $gte: value.substring(4) };
                      } else if (value.startsWith('lte:')) {
                        filterObj[key] = { $lte: value.substring(4) };
                      } else if (value.startsWith('ne:')) {
                        filterObj[key] = { $ne: value.substring(3) };
                      } else if (value.startsWith('regex:')) {
                        filterObj[key] = { $regex: value.substring(6), $options: 'i' };
                      } else {
                        filterObj[key] = value;
                      }
                    }
                  });
                }
              }
              
              // Add filter object to request
              req.filtering = filterObj;
              
              next();
            };
          };
          
          export default filtering;
        TYPESCRIPT
      else
        filtering_content = <<~JAVASCRIPT
          /**
           * Filtering middleware for Express.js
           * Adds filtering functionality to API requests
           */
          
          const filtering = (allowedFields = []) => {
            return (req, res, next) => {
              // Get filter parameters from query string
              const { filter } = req.query;
              
              // Initialize filter object
              let filterObj = {};
              
              if (filter) {
                try {
                  // Try to parse JSON filter
                  const parsedFilter = JSON.parse(filter);
                  
                  // If allowedFields is provided, only include those fields
                  if (allowedFields.length > 0) {
                    Object.keys(parsedFilter).forEach(key => {
                      if (allowedFields.includes(key)) {
                        filterObj[key] = parsedFilter[key];
                      }
                    });
                  } else {
                    filterObj = parsedFilter;
                  }
                } catch (error) {
                  // If JSON parsing fails, try to parse as simple key-value pairs
                  // Format: key1:value1,key2:value2
                  const filterParams = filter.split(',');
                  
                  filterParams.forEach(param => {
                    const [key, value] = param.split(':');
                    
                    if (key && value && (allowedFields.length === 0 || allowedFields.includes(key))) {
                      // Handle special operators
                      if (value.startsWith('gt:')) {
                        filterObj[key] = { $gt: value.substring(3) };
                      } else if (value.startsWith('lt:')) {
                        filterObj[key] = { $lt: value.substring(3) };
                      } else if (value.startsWith('gte:')) {
                        filterObj[key] = { $gte: value.substring(4) };
                      } else if (value.startsWith('lte:')) {
                        filterObj[key] = { $lte: value.substring(4) };
                      } else if (value.startsWith('ne:')) {
                        filterObj[key] = { $ne: value.substring(3) };
                      } else if (value.startsWith('regex:')) {
                        filterObj[key] = { $regex: value.substring(6), $options: 'i' };
                      } else {
                        filterObj[key] = value;
                      }
                    }
                  });
                }
              }
              
              // Add filter object to request
              req.filtering = filterObj;
              
              next();
            };
          };
          
          module.exports = filtering;
        JAVASCRIPT
      end
      
      File.write(filtering_file, filtering_content)
      log_info("Generated filtering middleware at #{filtering_file}")
    end
    
    def generate_api_features_utils(dir)
      # Determine file extension based on language
      file_ext = @language.to_s.downcase == "typescript" ? "ts" : "js"
      api_features_file = "#{dir}/apiFeatures.#{file_ext}"
      
      if @language.to_s.downcase == "typescript"
        api_features_content = <<~TYPESCRIPT
          /**
           * API Features utility for Express.js
           * Provides helper functions for pagination, sorting, and filtering
           */
          
          import { Query } from 'mongoose';

          interface QueryString {
            [key: string]: any;
            filter?: string;
            sort?: string;
            page?: string;
            limit?: string;
          }
          
          class APIFeatures<T> {
            query: Query<T[], T>;
            queryString: QueryString;
            
            constructor(query: Query<T[], T>, queryString: QueryString) {
              this.query = query;
              this.queryString = queryString;
            }
            
            /**
             * Apply filtering to the query
             * @param {Array} allowedFields - List of fields that can be filtered
             * @returns {APIFeatures} - Returns this for method chaining
             */
            filter(allowedFields: string[] = []): APIFeatures<T> {
              const { filter } = this.queryString;
              
              if (filter) {
                try {
                  // Try to parse JSON filter
                  const parsedFilter = JSON.parse(filter);
                  
                  // If allowedFields is provided, only include those fields
                  if (allowedFields.length > 0) {
                    const filteredObj: Record<string, any> = {};
                    
                    Object.keys(parsedFilter).forEach(key => {
                      if (allowedFields.includes(key)) {
                        filteredObj[key] = parsedFilter[key];
                      }
                    });
                    
                    this.query = this.query.find(filteredObj);
                  } else {
                    this.query = this.query.find(parsedFilter);
                  }
                } catch (error) {
                  // If JSON parsing fails, try to parse as simple key-value pairs
                  // Format: key1:value1,key2:value2
                  const filterParams = filter.split(',');
                  const filterObj: Record<string, any> = {};
                  
                  filterParams.forEach(param => {
                    const [key, value] = param.split(':');
                    
                    if (key && value && (allowedFields.length === 0 || allowedFields.includes(key))) {
                      // Handle special operators
                      if (value.startsWith('gt:')) {
                        filterObj[key] = { $gt: value.substring(3) };
                      } else if (value.startsWith('lt:')) {
                        filterObj[key] = { $lt: value.substring(3) };
                      } else if (value.startsWith('gte:')) {
                        filterObj[key] = { $gte: value.substring(4) };
                      } else if (value.startsWith('lte:')) {
                        filterObj[key] = { $lte: value.substring(4) };
                      } else if (value.startsWith('ne:')) {
                        filterObj[key] = { $ne: value.substring(3) };
                      } else if (value.startsWith('regex:')) {
                        filterObj[key] = { $regex: value.substring(6), $options: 'i' };
                      } else {
                        filterObj[key] = value;
                      }
                    }
                  });
                  
                  this.query = this.query.find(filterObj);
                }
              }
              
              return this;
            }
            
            /**
             * Apply sorting to the query
             * @param {Object} defaultSort - Default sort object
             * @returns {APIFeatures} - Returns this for method chaining
             */
            sort(defaultSort: Record<string, 1 | -1> = { createdAt: -1 }): APIFeatures<T> {
              const { sort } = this.queryString;
              
              if (sort) {
                // Parse sort parameter (format: field:direction,field:direction)
                // Example: name:asc,createdAt:desc
                const sortParams = sort.split(',');
                const sortObj: Record<string, 1 | -1> = {};
                
                sortParams.forEach(param => {
                  const [field, direction] = param.split(':');
                  
                  if (field && direction) {
                    // Convert direction to MongoDB format (1 for asc, -1 for desc)
                    sortObj[field] = direction.toLowerCase() === 'asc' ? 1 : -1;
                  }
                });
                
                this.query = this.query.sort(sortObj);
              } else {
                this.query = this.query.sort(defaultSort);
              }
              
              return this;
            }
            
            /**
             * Apply pagination to the query
             * @returns {APIFeatures} - Returns this for method chaining
             */
            paginate(): APIFeatures<T> {
              const page = parseInt(this.queryString.page || '1', 10);
              const limit = parseInt(this.queryString.limit || '10', 10);
              const skip = (page - 1) * limit;
              
              this.query = this.query.skip(skip).limit(limit);
              
              return this;
            }
          }
          
          export default APIFeatures;
        TYPESCRIPT
      else
        api_features_content = <<~JAVASCRIPT
          /**
           * API Features utility for Express.js
           * Provides helper functions for pagination, sorting, and filtering
           */
          
          class APIFeatures {
            constructor(query, queryString) {
              this.query = query;
              this.queryString = queryString;
            }
            
            /**
             * Apply filtering to the query
             * @param {Array} allowedFields - List of fields that can be filtered
             * @returns {APIFeatures} - Returns this for method chaining
             */
            filter(allowedFields = []) {
              const { filter } = this.queryString;
              
              if (filter) {
                try {
                  // Try to parse JSON filter
                  const parsedFilter = JSON.parse(filter);
                  
                  // If allowedFields is provided, only include those fields
                  if (allowedFields.length > 0) {
                    const filteredObj = {};
                    
                    Object.keys(parsedFilter).forEach(key => {
                      if (allowedFields.includes(key)) {
                        filteredObj[key] = parsedFilter[key];
                      }
                    });
                    
                    this.query = this.query.find(filteredObj);
                  } else {
                    this.query = this.query.find(parsedFilter);
                  }
                } catch (error) {
                  // If JSON parsing fails, try to parse as simple key-value pairs
                  // Format: key1:value1,key2:value2
                  const filterParams = filter.split(',');
                  const filterObj = {};
                  
                  filterParams.forEach(param => {
                    const [key, value] = param.split(':');
                    
                    if (key && value && (allowedFields.length === 0 || allowedFields.includes(key))) {
                      // Handle special operators
                      if (value.startsWith('gt:')) {
                        filterObj[key] = { $gt: value.substring(3) };
                      } else if (value.startsWith('lt:')) {
                        filterObj[key] = { $lt: value.substring(3) };
                      } else if (value.startsWith('gte:')) {
                        filterObj[key] = { $gte: value.substring(4) };
                      } else if (value.startsWith('lte:')) {
                        filterObj[key] = { $lte: value.substring(4) };
                      } else if (value.startsWith('ne:')) {
                        filterObj[key] = { $ne: value.substring(3) };
                      } else if (value.startsWith('regex:')) {
                        filterObj[key] = { $regex: value.substring(6), $options: 'i' };
                      } else {
                        filterObj[key] = value;
                      }
                    }
                  });
                  
                  this.query = this.query.find(filterObj);
                }
              }
              
              return this;
            }
            
            /**
             * Apply sorting to the query
             * @param {Object} defaultSort - Default sort object
             * @returns {APIFeatures} - Returns this for method chaining
             */
            sort(defaultSort = { createdAt: -1 }) {
              const { sort } = this.queryString;
              
              if (sort) {
                // Parse sort parameter (format: field:direction,field:direction)
                // Example: name:asc,createdAt:desc
                const sortParams = sort.split(',');
                const sortObj = {};
                
                sortParams.forEach(param => {
                  const [field, direction] = param.split(':');
                  
                  if (field && direction) {
                    // Convert direction to MongoDB format (1 for asc, -1 for desc)
                    sortObj[field] = direction.toLowerCase() === 'asc' ? 1 : -1;
                  }
                });
                
                this.query = this.query.sort(sortObj);
              } else {
                this.query = this.query.sort(defaultSort);
              }
              
              return this;
            }
            
            /**
             * Apply pagination to the query
             * @returns {APIFeatures} - Returns this for method chaining
             */
            paginate() {
              const page = parseInt(this.queryString.page || '1', 10);
              const limit = parseInt(this.queryString.limit || '10', 10);
              const skip = (page - 1) * limit;
              
              this.query = this.query.skip(skip).limit(limit);
              
              return this;
            }
          }
          
          module.exports = APIFeatures;
        JAVASCRIPT
      end
      
      File.write(api_features_file, api_features_content)
      log_info("Generated API features utility at #{api_features_file}")
    end
    
    def update_controller_templates
      # Determine templates directory based on language
      base_path = @language.to_s.downcase == "typescript" ? "#{@express_path}/src" : @express_path
      
      # Update controller templates based on database type
      case @database_type.to_s
      when 'mongodb', 'mongo'
        update_mongodb_controller_template(base_path)
      when 'sequelize', 'sql', 'mysql', 'postgres', 'postgresql'
        update_sequelize_controller_template(base_path)
      when 'prisma'
        update_prisma_controller_template(base_path)
      else
        log_info("Unknown database type: #{@database_type}, skipping controller template update")
      end
    end
    
    def update_mongodb_controller_template(base_path)
      # Create templates directory if it doesn't exist
      templates_dir = "#{base_path}/templates"
      FileUtils.mkdir_p(templates_dir)
      
      controller_template_file = "#{templates_dir}/controller.js.template"
      
      controller_template_content = <<~JAVASCRIPT
        const #{model_name} = require('../models/#{model_name}');
        const APIFeatures = require('../utils/apiFeatures');
        const catchAsync = require('../utils/catchAsync');
        
        // Get all #{model_name_plural}
        exports.getAll#{model_name_plural} = catchAsync(async (req, res) => {
          // Execute query with pagination, sorting, and filtering
          const features = new APIFeatures(#{model_name}.find(), req.query)
            .filter()
            .sort()
            .paginate()
            .select();
            
          const #{model_name_plural} = await features.query;
          
          // Get total count for pagination
          const total = await #{model_name}.countDocuments(req.filtering || {});
          
          // Send paginated response
          res.status(200).json(res.paginate(#{model_name_plural}, total));
        });
        
        // Get #{model_name} by ID
        exports.get#{model_name}ById = catchAsync(async (req, res) => {
          const #{model_name_camel} = await #{model_name}.findById(req.params.id);
          
          if (!#{model_name_camel}) {
            return res.status(404).json({ message: '#{model_name} not found' });
          }
          
          res.status(200).json({ data: #{model_name_camel} });
        });
        
        // Create new #{model_name}
        exports.create#{model_name} = catchAsync(async (req, res) => {
          const new#{model_name} = await #{model_name}.create(req.body);
          
          res.status(201).json({ data: new#{model_name} });
        });
        
        // Update #{model_name}
        exports.update#{model_name} = catchAsync(async (req, res) => {
          const #{model_name_camel} = await #{model_name}.findByIdAndUpdate(
            req.params.id,
            req.body,
            { new: true, runValidators: true }
          );
          
          if (!#{model_name_camel}) {
            return res.status(404).json({ message: '#{model_name} not found' });
          }
          
          res.status(200).json({ data: #{model_name_camel} });
        });
        
        // Delete #{model_name}
        exports.delete#{model_name} = catchAsync(async (req, res) => {
          const #{model_name_camel} = await #{model_name}.findByIdAndDelete(req.params.id);
          
          if (!#{model_name_camel}) {
            return res.status(404).json({ message: '#{model_name} not found' });
          }
          
          res.status(204).json({ data: null });
        });
      JAVASCRIPT
      
      File.write(controller_template_file, controller_template_content)
      log_info("Updated MongoDB controller template at #{controller_template_file}")
    end
    
    def update_sequelize_controller_template(base_path)
      # Create templates directory if it doesn't exist
      templates_dir = "#{base_path}/templates"
      FileUtils.mkdir_p(templates_dir)
      
      controller_template_file = "#{templates_dir}/controller.js.template"
      
      controller_template_content = <<~JAVASCRIPT
        const { #{model_name} } = require('../models');
        const catchAsync = require('../utils/catchAsync');
        
        // Get all #{model_name_plural}
        exports.getAll#{model_name_plural} = catchAsync(async (req, res) => {
          // Extract pagination parameters
          const { page = 1, limit = 10 } = req.query;
          const offset = (page - 1) * limit;
          
          // Extract sorting parameters
          const { sort } = req.query;
          let order = [['createdAt', 'DESC']];
          
          if (sort) {
            const sortParams = sort.split(',');
            order = sortParams.map(param => {
              const [field, direction] = param.split(':');
              return [field, direction.toUpperCase()];
            });
          }
          
          // Extract filtering parameters
          const where = req.filtering || {};
          
          // Execute query with pagination, sorting, and filtering
          const { count, rows } = await #{model_name}.findAndCountAll({
            where,
            order,
            limit: parseInt(limit, 10),
            offset: parseInt(offset, 10)
          });
          
          // Send paginated response
          res.status(200).json(res.paginate(rows, count));
        });
        
        // Get #{model_name} by ID
        exports.get#{model_name}ById = catchAsync(async (req, res) => {
          const #{model_name_camel} = await #{model_name}.findByPk(req.params.id);
          
          if (!#{model_name_camel}) {
            return res.status(404).json({ message: '#{model_name} not found' });
          }
          
          res.status(200).json({ data: #{model_name_camel} });
        });
        
        // Create new #{model_name}
        exports.create#{model_name} = catchAsync(async (req, res) => {
          const new#{model_name} = await #{model_name}.create(req.body);
          
          res.status(201).json({ data: new#{model_name} });
        });
        
        // Update #{model_name}
        exports.update#{model_name} = catchAsync(async (req, res) => {
          const #{model_name_camel} = await #{model_name}.findByPk(req.params.id);
          
          if (!#{model_name_camel}) {
            return res.status(404).json({ message: '#{model_name} not found' });
          }
          
          await #{model_name_camel}.update(req.body);
          
          res.status(200).json({ data: #{model_name_camel} });
        });
        
        // Delete #{model_name}
        exports.delete#{model_name} = catchAsync(async (req, res) => {
          const #{model_name_camel} = await #{model_name}.findByPk(req.params.id);
          
          if (!#{model_name_camel}) {
            return res.status(404).json({ message: '#{model_name} not found' });
          }
          
          await #{model_name_camel}.destroy();
          
          res.status(204).json({ data: null });
        });
      JAVASCRIPT
      
      File.write(controller_template_file, controller_template_content)
      log_info("Updated Sequelize controller template at #{controller_template_file}")
    end
    
    def update_prisma_controller_template(base_path)
      # Create templates directory if it doesn't exist
      templates_dir = "#{base_path}/templates"
      FileUtils.mkdir_p(templates_dir)
      
      controller_template_file = "#{templates_dir}/controller.js.template"
      
      controller_template_content = <<~JAVASCRIPT
        const { PrismaClient } = require('@prisma/client');
        const prisma = new PrismaClient();
        const catchAsync = require('../utils/catchAsync');
        
        // Get all #{model_name_plural}
        exports.getAll#{model_name_plural} = catchAsync(async (req, res) => {
          // Extract pagination parameters
          const { page = 1, limit = 10 } = req.query;
          const skip = (page - 1) * limit;
          
          // Extract sorting parameters
          const { sort } = req.query;
          let orderBy = { createdAt: 'desc' };
          
          if (sort) {
            orderBy = {};
            const sortParams = sort.split(',');
            
            sortParams.forEach(param => {
              const [field, direction] = param.split(':');
              orderBy[field] = direction.toLowerCase();
            });
          }
          
          // Extract filtering parameters
          const where = req.filtering || {};
          
          // Execute query with pagination, sorting, and filtering
          const #{model_name_plural} = await prisma.#{model_name_camel}.findMany({
            where,
            orderBy,
            skip: parseInt(skip, 10),
            take: parseInt(limit, 10)
          });
          
          // Get total count for pagination
          const total = await prisma.#{model_name_camel}.count({ where });
          
          // Send paginated response
          res.status(200).json(res.paginate(#{model_name_plural}, total));
        });
        
        // Get #{model_name} by ID
        exports.get#{model_name}ById = catchAsync(async (req, res) => {
          const #{model_name_camel} = await prisma.#{model_name_camel}.findUnique({
            where: { id: parseInt(req.params.id, 10) }
          });
          
          if (!#{model_name_camel}) {
            return res.status(404).json({ message: '#{model_name} not found' });
          }
          
          res.status(200).json({ data: #{model_name_camel} });
        });
        
        // Create new #{model_name}
        exports.create#{model_name} = catchAsync(async (req, res) => {
          const new#{model_name} = await prisma.#{model_name_camel}.create({
            data: req.body
          });
          
          res.status(201).json({ data: new#{model_name} });
        });
        
        // Update #{model_name}
        exports.update#{model_name} = catchAsync(async (req, res) => {
          try {
            const #{model_name_camel} = await prisma.#{model_name_camel}.update({
              where: { id: parseInt(req.params.id, 10) },
              data: req.body
            });
            
            res.status(200).json({ data: #{model_name_camel} });
          } catch (error) {
            if (error.code === 'P2025') {
              return res.status(404).json({ message: '#{model_name} not found' });
            }
            throw error;
          }
        });
        
        // Delete #{model_name}
        exports.delete#{model_name} = catchAsync(async (req, res) => {
          try {
            await prisma.#{model_name_camel}.delete({
              where: { id: parseInt(req.params.id, 10) }
            });
            
            res.status(204).json({ data: null });
          } catch (error) {
            if (error.code === 'P2025') {
              return res.status(404).json({ message: '#{model_name} not found' });
            }
            throw error;
          }
        });
      JAVASCRIPT
      
      File.write(controller_template_file, controller_template_content)
      log_info("Updated Prisma controller template at #{controller_template_file}")
    end
    
    # Helper methods for template variables
    def model_name
      '#{modelName}'
    end
    
    def model_name_plural
      '#{modelNamePlural}'
    end
    
    def model_name_camel
      '#{modelNameCamel}'
    end
  end
end 