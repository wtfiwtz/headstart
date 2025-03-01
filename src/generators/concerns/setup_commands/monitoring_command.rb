module Tenant
  module SetupCommands
    class MonitoringCommand < BaseCommand
      def execute(rails_path, configuration)
        return unless configuration&.monitoring&.any?
        
        FileUtils.chdir rails_path do
          # Create initializers directory if it doesn't exist
          FileUtils.mkdir_p "config/initializers"
          
          # Install each monitoring tool
          configuration.monitoring.each do |tool|
            case tool
            when :new_relic
              setup_new_relic(configuration)
            when :datadog
              setup_datadog(configuration)
            when :sentry
              setup_sentry(configuration)
            end
          end
        end
      end
      
      private
      
      def setup_new_relic(configuration)
        # Add New Relic gem if not already added
        unless configuration.gems.any? { |g| g[:name] == 'newrelic_rpm' }
          File.open("Gemfile", "a") do |f|
            f.puts "\n# New Relic"
            f.puts "gem 'newrelic_rpm'"
          end
          system "bundle install"
        end
        
        # Create New Relic configuration file
        File.open("config/newrelic.yml", "w") do |f|
          f.puts "common: &default_settings"
          f.puts "  license_key: '<%= ENV[\"NEW_RELIC_LICENSE_KEY\"] %>'"
          f.puts "  app_name: '#{File.basename(Dir.getwd)}'"
          f.puts "  distributed_tracing:"
          f.puts "    enabled: true"
          f.puts ""
          f.puts "development:"
          f.puts "  <<: *default_settings"
          f.puts "  app_name: '#{File.basename(Dir.getwd)} (Development)'"
          f.puts "  developer_mode: true"
          f.puts ""
          f.puts "test:"
          f.puts "  <<: *default_settings"
          f.puts "  monitor_mode: false"
          f.puts ""
          f.puts "production:"
          f.puts "  <<: *default_settings"
        end
        
        # Add environment variable instructions to README
        update_readme_with_env_vars("NEW_RELIC_LICENSE_KEY", "Your New Relic license key")
        
        puts "New Relic monitoring added successfully"
      end
      
      def setup_datadog(configuration)
        # Add Datadog gems if not already added
        datadog_gems = ['ddtrace', 'dogstatsd-ruby']
        datadog_gems.each do |gem_name|
          unless configuration.gems.any? { |g| g[:name] == gem_name }
            File.open("Gemfile", "a") do |f|
              f.puts "\n# Datadog" if gem_name == datadog_gems.first
              f.puts "gem '#{gem_name}'"
            end
          end
        end
        system "bundle install"
        
        # Create Datadog initializer
        File.open("config/initializers/datadog.rb", "w") do |f|
          f.puts "require 'ddtrace'"
          f.puts ""
          f.puts "Datadog.configure do |c|"
          f.puts "  c.use :rails, {"
          f.puts "    service_name: ENV['DD_SERVICE'] || '#{File.basename(Dir.getwd)}',"
          f.puts "    analytics_enabled: true"
          f.puts "  }"
          f.puts "  c.use :http"
          f.puts "  c.use :sidekiq if defined?(Sidekiq)"
          f.puts "  c.use :redis if defined?(Redis)"
          f.puts "end"
        end
        
        # Add environment variable instructions to README
        update_readme_with_env_vars("DD_SERVICE", "Your Datadog service name")
        update_readme_with_env_vars("DD_ENV", "Your environment (production, staging, etc.)")
        update_readme_with_env_vars("DD_API_KEY", "Your Datadog API key")
        
        puts "Datadog monitoring added successfully"
      end
      
      def setup_sentry(configuration)
        # Add Sentry gem if not already added
        unless configuration.gems.any? { |g| g[:name] == 'sentry-ruby' || g[:name] == 'sentry-rails' }
          File.open("Gemfile", "a") do |f|
            f.puts "\n# Sentry"
            f.puts "gem 'sentry-ruby'"
            f.puts "gem 'sentry-rails'"
            f.puts "gem 'sentry-sidekiq'" if configuration.features[:background_jobs]
          end
          system "bundle install"
        end
        
        # Create Sentry initializer
        File.open("config/initializers/sentry.rb", "w") do |f|
          f.puts "Sentry.init do |config|"
          f.puts "  config.dsn = ENV['SENTRY_DSN']"
          f.puts "  config.breadcrumbs_logger = [:active_support_logger, :http_logger]"
          f.puts "  config.traces_sample_rate = 0.5"
          f.puts "  config.environment = Rails.env"
          f.puts "  config.enabled_environments = %w[production staging]"
          f.puts "end"
        end
        
        # Add environment variable instructions to README
        update_readme_with_env_vars("SENTRY_DSN", "Your Sentry DSN")
        
        puts "Sentry error tracking added successfully"
      end
      
      def update_readme_with_env_vars(var_name, description)
        readme_path = "README.md"
        
        # Create README if it doesn't exist
        unless File.exist?(readme_path)
          File.open(readme_path, "w") do |f|
            f.puts "# #{File.basename(Dir.getwd)}"
            f.puts "\n## Environment Variables\n\n"
          end
        end
        
        # Add environment variable to README if not already there
        readme_content = File.read(readme_path)
        
        unless readme_content.include?("## Environment Variables")
          File.open(readme_path, "a") do |f|
            f.puts "\n## Environment Variables\n\n"
          end
          readme_content = File.read(readme_path)
        end
        
        unless readme_content.include?(var_name)
          env_vars_section = readme_content.match(/## Environment Variables\s*\n(.*?)(\n##|\z)/m)
          
          if env_vars_section
            updated_section = env_vars_section[1] + "- `#{var_name}`: #{description}\n"
            updated_readme = readme_content.sub(env_vars_section[1], updated_section)
            File.write(readme_path, updated_readme)
          else
            File.open(readme_path, "a") do |f|
              f.puts "- `#{var_name}`: #{description}"
            end
          end
        end
      end
    end
  end
end 