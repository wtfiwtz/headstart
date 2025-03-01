module Tenant
  module SetupCommands
    class ControllerInheritanceCommand < BaseCommand
      def execute(rails_path, configuration)
        return unless configuration&.controller_inheritance
        
        FileUtils.mkdir_p "#{rails_path}/app/controllers/generated"
        
        # Create an initializer to autoload the Generated namespace
        FileUtils.mkdir_p "#{rails_path}/config/initializers"
        File.open("#{rails_path}/config/initializers/generated_controllers.rb", 'w') do |f|
          f.puts "# Ensure the Generated module is autoloaded"
          f.puts "Rails.application.config.to_prepare do"
          f.puts "  # Explicitly load all generated controllers"
          f.puts "  Dir.glob(Rails.root.join('app/controllers/generated/**/*_controller.rb')).each do |controller|"
          f.puts "    require_dependency controller"
          f.puts "  end"
          f.puts "end"
        end
      end
    end
  end
end 