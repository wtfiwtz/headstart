module Tenant
  module ExpressTemplateHandler
    def generate_utils
      # Create a utility file for API responses
      api_response = <<~JS
        /**
         * Standard API response formatter
         */
        const apiResponse = {
          success: (res, data, message = 'Operation successful', statusCode = 200) => {
            return res.status(statusCode).json({
              status: 'success',
              message,
              data
            });
          },
          
          error: (res, message = 'An error occurred', statusCode = 500, errors = null) => {
            const response = {
              status: 'error',
              message
            };
            
            if (errors) {
              response.errors = errors;
            }
            
            return res.status(statusCode).json(response);
          }
        };
        
        module.exports = apiResponse;
      JS
      
      File.write("#{@express_path}/utils/api_response.js", api_response)
      
      # Create a validation utility
      validation_util = <<~JS
        /**
         * Validation utility functions
         */
        const validationUtils = {
          isValidEmail: (email) => {
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            return emailRegex.test(email);
          },
          
          isValidPassword: (password) => {
            // At least 8 characters, 1 uppercase, 1 lowercase, 1 number
            const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d]{8,}$/;
            return passwordRegex.test(password);
          },
          
          sanitizeInput: (input) => {
            // Basic sanitization
            if (typeof input === 'string') {
              return input.trim();
            }
            return input;
          }
        };
        
        module.exports = validationUtils;
      JS
      
      File.write("#{@express_path}/utils/validation.js", validation_util)
    end
    
    def generate_error_classes
      # Create custom error classes
      error_classes = <<~JS
        /**
         * Custom error classes for the application
         */
        
        class AppError extends Error {
          constructor(message, statusCode) {
            super(message);
            this.statusCode = statusCode;
            this.status = `${statusCode}`.startsWith('4') ? 'fail' : 'error';
            this.isOperational = true;
            
            Error.captureStackTrace(this, this.constructor);
          }
        }
        
        class NotFoundError extends AppError {
          constructor(message = 'Resource not found') {
            super(message, 404);
          }
        }
        
        class ValidationError extends AppError {
          constructor(message = 'Validation failed') {
            super(message, 400);
          }
        }
        
        class UnauthorizedError extends AppError {
          constructor(message = 'Unauthorized access') {
            super(message, 401);
          }
        }
        
        class ForbiddenError extends AppError {
          constructor(message = 'Forbidden access') {
            super(message, 403);
          }
        }
        
        module.exports = {
          AppError,
          NotFoundError,
          ValidationError,
          UnauthorizedError,
          ForbiddenError
        };
      JS
      
      File.write("#{@express_path}/utils/errors.js", error_classes)
    end
  end
end 