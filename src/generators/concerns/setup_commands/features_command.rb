module Tenant
  module SetupCommands
    class FeaturesCommand < BaseCommand
      def execute(rails_path, configuration)
        return unless configuration&.features&.any?
        
        FileUtils.chdir rails_path do
          # Handle authentication
          if configuration.features[:authentication]
            setup_authentication(configuration.features[:authentication])
          end
          
          # Handle file uploads
          if configuration.features[:file_upload]
            setup_file_upload(configuration.features[:file_upload])
          end
          
          # Handle background jobs
          if configuration.features[:background_jobs]
            setup_background_jobs(configuration.features[:background_jobs])
          end
        end
      end
      
      private
      
      def setup_authentication(auth_config)
        auth_type = auth_config[:provider] || :rodauth
        
        case auth_type
        when :rodauth
          system "rails generate rodauth:install"
          configure_rodauth(auth_config)
        when :devise
          system "rails generate devise:install"
          system "rails generate devise User" if auth_config[:generate_user]
        end
      end
      
      def configure_rodauth(options)
        # Implementation for configuring Rodauth
        # ...
      end
      
      def setup_file_upload(upload_config)
        upload_type = upload_config[:provider] || :active_storage
        
        case upload_type
        when :active_storage
          system "rails active_storage:install"
          system "rails db:migrate"
        when :shrine
          # Setup shrine configuration
        end
      end
      
      def setup_background_jobs(jobs_config)
        job_type = jobs_config[:provider] || :sidekiq
        
        case job_type
        when :sidekiq
          # Add Sidekiq configuration
          FileUtils.mkdir_p "config/initializers"
          File.open("config/initializers/sidekiq.rb", "w") do |f|
            f.puts "Sidekiq.configure_server do |config|"
            f.puts "  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }"
            f.puts "end"
            f.puts ""
            f.puts "Sidekiq.configure_client do |config|"
            f.puts "  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }"
            f.puts "end"
          end
          
          # Add Sidekiq routes
          routes_path = "config/routes.rb"
          routes_content = File.read(routes_path)
          
          unless routes_content.include?("Sidekiq::Web")
            routes_block_match = routes_content.match(/Rails\.application\.routes\.draw do\s*\n(.*?)\nend/m)
            
            if routes_block_match
              routes_content = routes_block_match[1]
              
              sidekiq_routes = <<~ROUTES
                
                # Sidekiq Web UI
                require 'sidekiq/web'
                authenticate :user, lambda { |u| u.admin? } do
                  mount Sidekiq::Web => '/sidekiq'
                end
              ROUTES
              
              updated_routes = routes_content.sub(
                /Rails\.application\.routes\.draw do\s*\n.*?\nend/m,
                "Rails.application.routes.draw do\n#{routes_content}#{sidekiq_routes}\nend"
              )
              
              File.write(routes_path, updated_routes)
            end
          end
        end
      end
    end
  end
end 