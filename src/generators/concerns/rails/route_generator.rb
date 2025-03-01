module Tenant
  module RouteGenerator
    def generate_routes
      routes_path = "#{@rails_all_path}/config/routes.rb"
      
      # Read the current routes file
      current_routes = File.read(routes_path)
      
      # Find the Rails.application.routes.draw block
      routes_block_match = current_routes.match(/Rails\.application\.routes\.draw do\s*\n(.*?)\nend/m)
      
      if routes_block_match
        # Extract the current routes content
        routes_content = routes_block_match[1]
        
        # Generate new routes for each model
        new_routes = generate_routes_for_models
        
        # Check if the routes already exist
        new_routes.each do |route|
          unless routes_content.include?(route.strip)
            routes_content += "  #{route}\n"
          end
        end
        
        # Replace the routes block with the updated content
        updated_routes = current_routes.sub(
          /Rails\.application\.routes\.draw do\s*\n.*?\nend/m,
          "Rails.application.routes.draw do\n#{routes_content}\nend"
        )
        
        # Write the updated routes back to the file
        File.write(routes_path, updated_routes)
        
        puts "Updated routes in config/routes.rb"
      else
        puts "Could not find the routes block in config/routes.rb"
      end
    end
    
    def generate_routes_for_models
      routes = []
      
      # Process each model to generate appropriate routes
      @models.each do |model|
        routes.concat(generate_routes_for_model(model))
      end
      
      # Add root route if we have a suitable model
      root_route = determine_root_route
      routes << root_route if root_route
      
      routes
    end
    
    def generate_routes_for_model(model)
      model_routes = []
      model_name = model.name.to_s
      plural_name = model_name.pluralize
      
      # Check for nested resources
      nested_resources = find_nested_resources(model)
      
      if nested_resources.any?
        # Generate nested routes
        nested_resources.each do |parent_model|
          model_routes.concat(generate_nested_routes(parent_model, model))
        end
      else
        # Generate standard RESTful routes
        model_routes << "resources :#{plural_name}"
      end
      
      # Add member and collection routes if needed
      member_routes = generate_member_routes(model)
      collection_routes = generate_collection_routes(model)
      
      if member_routes.any? || collection_routes.any?
        # Remove the simple route if we're going to replace it with a block
        model_routes.delete("resources :#{plural_name}")
        model_routes.concat(generate_resource_block(plural_name, member_routes, collection_routes))
      end
      
      model_routes
    end
    
    def generate_nested_routes(parent_model, child_model)
      parent_name = parent_model.name.to_s
      parent_plural = parent_name.pluralize
      child_plural = child_model.name.to_s.pluralize
      
      [
        "resources :#{parent_plural} do",
        "  resources :#{child_plural}",
        "end"
      ]
    end
    
    def generate_resource_block(resource_name, member_routes, collection_routes)
      route_block = ["resources :#{resource_name} do"]
      
      if member_routes.any?
        route_block << "  member do"
        member_routes.each do |member_route|
          route_block << "    #{member_route}"
        end
        route_block << "  end"
      end
      
      if collection_routes.any?
        route_block << "  collection do"
        collection_routes.each do |collection_route|
          route_block << "    #{collection_route}"
        end
        route_block << "  end"
      end
      
      route_block << "end"
      route_block
    end
    
    def find_nested_resources(model)
      # Find models that this model belongs to
      nested_resources = []
      
      model.associations.each do |assoc|
        if assoc[:kind] == :belongs_to
          # Find the parent model
          parent_model = @models.find { |m| m.name.to_s == assoc[:name].to_s.singularize }
          nested_resources << parent_model if parent_model
        end
      end
      
      nested_resources
    end
    
    def generate_member_routes(model)
      member_routes = []
      
      # Add common member routes based on model attributes
      if model.attributes.keys.include?(:active) || model.attributes.keys.include?(:status)
        member_routes << "get :activate"
        member_routes << "get :deactivate"
      end
      
      if model.attributes.keys.include?(:position)
        member_routes << "put :move_up"
        member_routes << "put :move_down"
      end
      
      # Add archive/unarchive if there's an archived_at attribute
      if model.attributes.keys.include?(:archived_at)
        member_routes << "put :archive"
        member_routes << "put :unarchive"
      end
      
      member_routes
    end
    
    def generate_collection_routes(model)
      collection_routes = []
      
      # Add common collection routes
      if model.attributes.keys.include?(:active) || model.attributes.keys.include?(:status)
        collection_routes << "get :active"
        collection_routes << "get :inactive"
      end
      
      # Add export routes if it's a data-heavy model
      if model.attributes.keys.count >= 5
        collection_routes << "get :export"
      end
      
      # Add import route if it makes sense for this model
      if model.name.to_s.in?(%w[product user customer account])
        collection_routes << "post :import"
      end
      
      # Add search if the model has searchable attributes
      searchable_attrs = [:name, :title, :description, :email, :username].select do |attr|
        model.attributes.keys.include?(attr)
      end
      
      if searchable_attrs.any?
        collection_routes << "get :search"
      end
      
      collection_routes
    end
    
    def determine_root_route
      # Try to find a suitable model for the root route
      dashboard_model = @models.find { |m| m.name.to_s == 'dashboard' }
      return "root to: 'dashboards#index'" if dashboard_model
      
      home_model = @models.find { |m| m.name.to_s == 'home' }
      return "root to: 'homes#index'" if home_model
      
      # Look for common models that might serve as a landing page
      %w[post article page product].each do |model_name|
        model = @models.find { |m| m.name.to_s == model_name }
        return "root to: '#{model_name.pluralize}#index'" if model
      end
      
      # Default to the first model if nothing else is suitable
      return "root to: '#{@models.first.name.to_s.pluralize}#index'" if @models.any?
      
      nil
    end
  end
end 