module Tenant
  module SetupCommands
    class FormBuilderCommand < BaseCommand
      def execute(rails_path, configuration)
        return unless configuration&.form_builder && configuration.form_builder != :default
        
        FileUtils.chdir rails_path do
          case configuration.form_builder
          when :simple_form
            setup_simple_form(configuration)
          when :formtastic
            setup_formtastic(configuration)
          end
        end
      end
      
      private
      
      def setup_simple_form(configuration)
        # Add Simple Form gem if not already added
        unless configuration.gems.any? { |g| g[:name] == 'simple_form' }
          File.open("Gemfile", "a") do |f|
            f.puts "\n# Simple Form"
            f.puts "gem 'simple_form'"
          end
          system "bundle install"
        end
        
        # Install Simple Form
        if configuration.css_framework == :bootstrap
          system "rails generate simple_form:install --bootstrap"
        else
          system "rails generate simple_form:install"
        end
        
        puts "Simple Form installed successfully"
      end
      
      def setup_formtastic(configuration)
        # Add Formtastic gem if not already added
        unless configuration.gems.any? { |g| g[:name] == 'formtastic' }
          File.open("Gemfile", "a") do |f|
            f.puts "\n# Formtastic"
            f.puts "gem 'formtastic'"
          end
          system "bundle install"
        end
        
        # Install Formtastic
        system "rails generate formtastic:install"
        
        puts "Formtastic installed successfully"
      end
    end
  end
end 