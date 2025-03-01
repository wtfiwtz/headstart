module Tenant
  module ControllerGenerator
    def generate_controllers
      log_info("Generating controllers for #{@models.length} models")
      
      @models.each do |model|
        generate_controller(model)
      end
    end
    
    private
    
    def generate_controller(model)
      log_info("Generating controller for #{model.name}")
      
      # Create the controller file
      controller_path = "#{@rails_all_path}/app/controllers/#{model.name.underscore.pluralize}_controller.rb"
      
      # Create the controller content
      controller_content = generate_controller_content(model)
      
      # Write the controller file
      File.write(controller_path, controller_content)
      
      # If using controller inheritance, also generate a base controller
      if @configuration&.controller_inheritance
        generate_derived_controller(model)
      end
    end
    
    def generate_controller_content(model)
      template_path = "#{@templates_path}/template_controller.rb.erb"
      template = File.read(template_path)
      
      # Create a binding with the model
      controller_binding = binding
      
      # Evaluate the template with the binding
      ERB.new(template).result(controller_binding)
    end
    
    def generate_derived_controller(model)
      # Create the derived controller file
      controller_path = "#{@rails_all_path}/app/controllers/generated/#{model.name.underscore.pluralize}_controller.rb"
      
      # Ensure the directory exists
      FileUtils.mkdir_p(File.dirname(controller_path))
      
      # Create the controller content
      controller_content = generate_derived_controller_content(model)
      
      # Write the controller file
      File.write(controller_path, controller_content)
    end
    
    def generate_derived_controller_content(model)
      template_path = "#{@templates_path}/template_derived_controller.rb.erb"
      template = File.read(template_path)
      
      # Create a binding with the model
      controller_binding = binding
      
      # Evaluate the template with the binding
      ERB.new(template).result(controller_binding)
    end
  end
end 