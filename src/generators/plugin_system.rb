module Tenant
  class PluginSystem
    def self.plugins
      @plugins ||= []
    end
    
    def self.register_plugin(plugin)
      plugins << plugin
    end
    
    def self.run_hooks(hook_name, *args)
      plugins.each do |plugin|
        plugin.send(hook_name, *args) if plugin.respond_to?(hook_name)
      end
    end
  end
  
  # Base plugin class that plugins can inherit from
  class Plugin
    def self.register
      PluginSystem.register_plugin(new)
    end
    
    # Hook methods that can be overridden by plugins
    def before_generate(models)
      # Do nothing by default
    end
    
    def after_generate(models)
      # Do nothing by default
    end
    
    def before_model_generate(model)
      # Do nothing by default
    end
    
    def after_model_generate(model)
      # Do nothing by default
    end
    
    def before_controller_generate(model)
      # Do nothing by default
    end
    
    def after_controller_generate(model)
      # Do nothing by default
    end
    
    def before_view_generate(model)
      # Do nothing by default
    end
    
    def after_view_generate(model)
      # Do nothing by default
    end
    
    def before_routes_generate
      # Do nothing by default
    end
    
    def after_routes_generate
      # Do nothing by default
    end
  end
end 