module Tenant
  module RouteGenerator
    require 'set'

    def generate_routes
      routes_path = "#{@rails_all_path}/config/routes.rb"
      
      routes = ["Rails.application.routes.draw do"]
      
      # Generate standalone resources first
      standalone_resources = @models.reject { |m| find_nested_resources(m).any? }
      standalone_resources.each do |model|
        routes.concat(generate_routes_for_model(model).map { |r| "  #{r}" })
      end
      
      # Generate nested resources
      processed = Set.new
      @models.each do |model|
        next if processed.include?(model.name.to_s)
        
        nested_resources = find_nested_resources(model)
        next unless nested_resources.any?
        
        nested_resources.each do |parent|
          next if processed.include?(parent.name.to_s)
          
          # Generate parent resource with its nested resources
          parent_routes = generate_standalone_resource(parent)
          child_routes = ["    resources :#{model.name.to_s.pluralize}"]
          
          routes << "  resources :#{parent.name.to_s.pluralize} do"
          routes.concat(parent_routes.map { |r| "    #{r}" })
          routes.concat(child_routes)
          routes << "  end"
          
          processed.add(parent.name.to_s)
          processed.add(model.name.to_s)
        end
      end
      
      # Add root route
      if root = determine_root_route
        routes << "  #{root}"
      end
      
      routes << "end"
      
      # Write routes file
      File.write(routes_path, routes.join("\n") + "\n")
      puts "*** Here's the routes file:"
      puts routes.join("\n") + "\n"
      puts "Generated routes in config/routes.rb"
    end

    def generate_standalone_resource(model)
      routes = []
      
      member = member_routes(model)
      collection = collection_routes(model)
      
      if member.any?
        routes << "member do"
        member.each { |r| routes << "  #{r}" }
        routes << "end"
      end
      
      if collection.any?
        routes << "collection do"
        collection.each { |r| routes << "  #{r}" }
        routes << "end"
      end
      
      routes
    end

    def generate_routes_for_model(model)
      name = model.name.to_s.pluralize
      member = member_routes(model)
      collection = collection_routes(model)
      
      if member.any? || collection.any?
        routes = ["resources :#{name} do"]
        
        if member.any?
          routes << "    member do"
          member.each { |r| routes << "      #{r}" }
          routes << "    end"
        end
        
        if collection.any?
          routes << "    collection do"
          collection.each { |r| routes << "      #{r}" }
          routes << "    end"
        end
        
        routes << "  end"
        routes
      else
        ["resources :#{name}"]
      end
    end

    def find_nested_resources(model)
      nested_resources = []
      
      model.associations.each do |assoc|
        if assoc[:kind] == :belongs_to
          parent_model = @models.find { |m| m.name.to_s == assoc[:name].to_s.singularize }
          nested_resources << parent_model if parent_model
        end
      end
      
      nested_resources
    end

    def member_routes(model)
      routes = []
      
      if model.attributes.keys.include?(:active) || model.attributes.keys.include?(:status)
        routes << "get :activate"
        routes << "get :deactivate"
      end
      
      if model.attributes.keys.include?(:position)
        routes << "put :move_up"
        routes << "put :move_down"
      end
      
      if model.attributes.keys.include?(:archived_at)
        routes << "put :archive"
        routes << "put :unarchive"
      end
      
      routes
    end

    def collection_routes(model)
      routes = []
      
      if model.attributes.keys.include?(:active) || model.attributes.keys.include?(:status)
        routes << "get :active"
        routes << "get :inactive"
      end
      
      if model.attributes.keys.count >= 5
        routes << "get :export"
      end
      
      importable_modules = %w[product user customer account]
      if importable_modules.any? { |m| model.name.to_s.downcase.include?(m) }
        routes << "post :import"
      end
      
      searchable_attrs = [:name, :title, :description, :email, :username].select do |attr|
        model.attributes.keys.include?(attr)
      end
      
      if searchable_attrs.any?
        routes << "get :search"
      end
      
      routes
    end

    def determine_root_route
      dashboard_model = @models.find { |m| m.name.to_s == 'dashboard' }
      return "root to: 'dashboards#index'" if dashboard_model
      
      home_model = @models.find { |m| m.name.to_s == 'home' }
      return "root to: 'homes#index'" if home_model
      
      %w[post article page product].each do |model_name|
        model = @models.find { |m| m.name.to_s == model_name }
        return "root to: '#{model_name.pluralize}#index'" if model
      end
      
      return "root to: '#{@models.first.name.to_s.pluralize}#index'" if @models.any?
      
      nil
    end
  end
end 