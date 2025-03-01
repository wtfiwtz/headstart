module Tenant
  module ConfigurationHandler
    def setup_target
      return if Dir.exist?("#{__dir__}/../../out/rails_app")

      FileUtils.mkdir_p "#{__dir__}/../../out"
      FileUtils.chdir "#{__dir__}/../../out"

      create_rails_app
      setup_controller_inheritance if @configuration&.controller_inheritance
      install_gems if @configuration&.gems&.any?
      setup_css_framework if @configuration&.css_framework != :none
      setup_form_builder if @configuration&.form_builder != :default
      setup_features if @configuration&.features&.any?
      setup_monitoring if @configuration&.monitoring&.any?
    end
    
    def create_rails_app
      # Build the rails new command with appropriate options
      rails_new_cmd = "rails new rails_app"
      
      # Add database option
      case @configuration&.database
      when :postgresql
        rails_new_cmd += " --database=postgresql"
      when :mysql
        rails_new_cmd += " --database=mysql"
      else
        # Default to SQLite
        rails_new_cmd += " --database=sqlite3"
      end
      
      # Add frontend option
      case @configuration&.frontend
      when :react
        rails_new_cmd += " --webpack=react"
      when :vue
        rails_new_cmd += " --webpack=vue"
      end
      
      # Execute the rails new command
      system rails_new_cmd
      
      # Configure database.yml if needed
      configure_database if @configuration&.database_options&.any?
    end
    
    def configure_database
      return unless @configuration&.database
      
      database_yml_path = "#{@rails_all_path}/config/database.yml"
      return unless File.exist?(database_yml_path)
      
      database_config = YAML.load_file(database_yml_path)
      
      # Apply custom database options
      if @configuration.database_options.any?
        [:development, :test, :production].each do |env|
          next unless database_config[env.to_s]
          
          @configuration.database_options.each do |key, value|
            database_config[env.to_s][key.to_s] = value
          end
        end
        
        # Write updated database.yml
        File.write(database_yml_path, database_config.to_yaml)
      end
      
      # For PostgreSQL, ensure the pg gem is installed
      if @configuration.database == :postgresql
        unless @configuration.gems.any? { |g| g[:name] == 'pg' }
          @configuration.add_gem('pg', '~> 1.4')
        end
      end
      
      # For MySQL, ensure the mysql2 gem is installed
      if @configuration.database == :mysql
        unless @configuration.gems.any? { |g| g[:name] == 'mysql2' }
          @configuration.add_gem('mysql2', '~> 0.5')
        end
      end
    end
    
    def setup_controller_inheritance
      FileUtils.mkdir_p "#{@rails_all_path}/app/controllers/generated"
      
      # Create an initializer to autoload the Generated namespace
      FileUtils.mkdir_p "#{@rails_all_path}/config/initializers"
      File.open("#{@rails_all_path}/config/initializers/generated_controllers.rb", 'w') do |f|
        f.puts "# Ensure the Generated module is autoloaded"
        f.puts "Rails.application.config.to_prepare do"
        f.puts "  # Explicitly load all generated controllers"
        f.puts "  Dir.glob(Rails.root.join('app/controllers/generated/**/*_controller.rb')).each do |controller|"
        f.puts "    require_dependency controller"
        f.puts "  end"
        f.puts "end"
      end
    end
    
    def install_gems
      return unless @configuration&.gems&.any?
      
      gemfile_path = "#{@rails_all_path}/Gemfile"
      gemfile_content = File.read(gemfile_path)
      
      # Add required gems for API functionality
      required_api_gems = [
        { name: 'pagy', version: '~> 6.0' },      # For pagination
        { name: 'ransack', version: '~> 4.0' },   # For advanced filtering
        { name: 'oj', version: '~> 3.14' },       # For faster JSON serialization
        { name: 'rack-cors', version: '~> 2.0' }  # For CORS support
      ]
      
      # Add the required API gems if they're not already in the configuration
      required_api_gems.each do |gem_info|
        unless @configuration.gems.any? { |g| g[:name] == gem_info[:name] }
          @configuration.gems << Tenant::Configuration::GemConfiguration.new(gem_info[:name], gem_info[:version])
        end
      end
      
      # Add search engine gems if configured
      setup_search_engine_gems if @configuration&.search_engine
      
      @configuration.gems.each do |gem_info|
        gem_line = "gem '#{gem_info[:name]}'"
        gem_line += ", '#{gem_info[:version]}'" if gem_info[:version]
        
        if gem_info[:options].any?
          options_string = gem_info[:options].map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
          gem_line += ", #{options_string}"
        end
        
        unless gemfile_content.include?(gem_line)
          File.open(gemfile_path, 'a') do |f|
            f.puts "\n#{gem_line}"
          end
          puts "Added #{gem_info[:name]} to Gemfile"
        end
      end
      
      # Install gems
      FileUtils.chdir @rails_all_path do
        system "bundle install"
      end
      
      # Create initializers for API-related gems
      setup_api_initializers
      
      # Setup search engine if configured
      setup_search_engine if @configuration&.search_engine
    end
    
    def setup_search_engine_gems
      case @configuration.search_engine
      when :elasticsearch
        # Add Elasticsearch gems
        unless @configuration.gems.any? { |g| g[:name] == 'elasticsearch-model' }
          @configuration.add_gem('elasticsearch-model', '~> 7.2')
          @configuration.add_gem('elasticsearch-rails', '~> 7.2')
          @configuration.add_gem('elasticsearch-persistence', '~> 7.2')
        end
      when :meilisearch
        # Add MeiliSearch gems
        unless @configuration.gems.any? { |g| g[:name] == 'meilisearch-rails' }
          @configuration.add_gem('meilisearch-rails', '~> 0.8')
        end
      end
      
    def setup_search_engine
      FileUtils.chdir @rails_all_path do
        case @configuration.search_engine
        when :elasticsearch
          setup_elasticsearch
        when :meilisearch
          setup_meilisearch
        end
      end
    end
    
    def setup_elasticsearch
      # Create Elasticsearch initializer
      FileUtils.mkdir_p "#{@rails_all_path}/config/initializers"
      
      File.open("#{@rails_all_path}/config/initializers/elasticsearch.rb", "w") do |f|
        f.puts "# Elasticsearch configuration"
        f.puts "require 'elasticsearch/model'"
        f.puts ""
        f.puts "# Set Elasticsearch URL from environment variable or use default"
        f.puts "Elasticsearch::Model.client = Elasticsearch::Client.new("
        f.puts "  url: ENV['ELASTICSEARCH_URL'] || 'http://localhost:9200',"
        f.puts "  transport_options: {"
        f.puts "    request: { timeout: 5 }"
        f.puts "  }"
        f.puts ")"
        f.puts ""
        f.puts "# Configure Searchkick to use Elasticsearch"
        f.puts "Searchkick.client = Elasticsearch::Model.client"
        f.puts "Searchkick.index_prefix = Rails.env"
      end
      
      # Create a concern for Elasticsearch integration
      FileUtils.mkdir_p "#{@rails_all_path}/app/models/concerns"
      
      File.open("#{@rails_all_path}/app/models/concerns/searchable.rb", "w") do |f|
        f.puts "module Searchable"
        f.puts "  extend ActiveSupport::Concern"
        f.puts ""
        f.puts "  included do"
        f.puts "    include Elasticsearch::Model"
        f.puts "    include Elasticsearch::Model::Callbacks"
        f.puts ""
        f.puts "    # Define the Elasticsearch index settings"
        f.puts "    settings index: { number_of_shards: 1, number_of_replicas: 0 } do"
        f.puts "      mapping do"
        f.puts "        # Add dynamic templates for different field types"
        f.puts "        dynamic_templates do"
        f.puts "          template :string_template do"
        f.puts "            match_mapping_type 'string'"
        f.puts "            mapping analyzer: 'english'"
        f.puts "          end"
        f.puts "        end"
        f.puts "      end"
        f.puts "    end"
        f.puts ""
        f.puts "    # Define what fields to index in Elasticsearch"
        f.puts "    def as_indexed_json(options = {})"
        f.puts "      self.as_json("
        f.puts "        only: self.class.searchable_fields,"
        f.puts "        include: self.class.searchable_associations"
        f.puts "      )"
        f.puts "    end"
        f.puts "  end"
        f.puts ""
        f.puts "  class_methods do"
        f.puts "    # Define which fields are searchable (override in each model)"
        f.puts "    def searchable_fields"
        f.puts "      []"
        f.puts "    end"
        f.puts ""
        f.puts "    # Define which associations to include in search (override in each model)"
        f.puts "    def searchable_associations"
        f.puts "      {}"
        f.puts "    end"
        f.puts ""
        f.puts "    # Search method with highlighting"
        f.puts "    def search_with_highlights(query, options = {})"
        f.puts "      search_definition = {"
        f.puts "        query: {"
        f.puts "          multi_match: {"
        f.puts "            query: query,"
        f.puts "            fields: searchable_fields,"
        f.puts "            fuzziness: 'AUTO'"
        f.puts "          }"
        f.puts "        },"
        f.puts "        highlight: {"
        f.puts "          pre_tags: ['<em class=\"highlight\">'],"
        f.puts "          post_tags: ['</em>'],"
        f.puts "          fields: {"
        f.puts "            '*': {}"
        f.puts "          }"
        f.puts "        }"
        f.puts "      }"
        f.puts ""
        f.puts "      # Add pagination if provided"
        f.puts "      if options[:page] && options[:per_page]"
        f.puts "        search_definition[:from] = (options[:page].to_i - 1) * options[:per_page].to_i"
        f.puts "        search_definition[:size] = options[:per_page].to_i"
        f.puts "      end"
        f.puts ""
        f.puts "      # Add sorting if provided"
        f.puts "      if options[:sort]"
        f.puts "        field, direction = options[:sort].split(':')"
        f.puts "        search_definition[:sort] = { field => { order: direction || 'asc' } }"
        f.puts "      end"
        f.puts ""
        f.puts "      # Execute search"
        f.puts "      __elasticsearch__.search(search_definition)"
        f.puts "    end"
        f.puts "  end"
        f.puts "end"
      end
      
      # Add environment variable instructions to README
      update_readme_with_env_vars("ELASTICSEARCH_URL", "URL for your Elasticsearch instance (default: http://localhost:9200)")
      
      puts "Elasticsearch configured successfully"
    end
    
    def setup_meilisearch
      # Create MeiliSearch initializer
      FileUtils.mkdir_p "#{@rails_all_path}/config/initializers"
      
      File.open("#{@rails_all_path}/config/initializers/meilisearch.rb", "w") do |f|
        f.puts "# MeiliSearch configuration"
        f.puts "MeiliSearch::Rails.configuration = {"
        f.puts "  host: ENV['MEILISEARCH_HOST'] || 'http://localhost:7700',"
        f.puts "  api_key: ENV['MEILISEARCH_API_KEY'],"
        f.puts "  timeout: 2,"
        f.puts "  max_retries: 1"
        f.puts "}"
        f.puts ""
        f.puts "# Configure Searchkick to use MeiliSearch"
        f.puts "Searchkick.backend = :meilisearch"
        f.puts "Searchkick.meilisearch_host = ENV['MEILISEARCH_HOST'] || 'http://localhost:7700'"
        f.puts "Searchkick.meilisearch_api_key = ENV['MEILISEARCH_API_KEY']"
      end
      
      # Create a concern for MeiliSearch integration
      FileUtils.mkdir_p "#{@rails_all_path}/app/models/concerns"
      
      File.open("#{@rails_all_path}/app/models/concerns/searchable.rb", "w") do |f|
        f.puts "module Searchable"
        f.puts "  extend ActiveSupport::Concern"
        f.puts ""
        f.puts "  included do"
        f.puts "    searchkick word_start: searchkick_word_start_fields,"
        f.puts "               word_middle: searchkick_word_middle_fields,"
        f.puts "               text_start: searchkick_text_start_fields,"
        f.puts "               text_middle: searchkick_text_middle_fields,"
        f.puts "               highlight: searchkick_highlight_fields"
        f.puts ""
        f.puts "    # Callbacks to reindex when a record is updated"
        f.puts "    after_commit :reindex, if: -> { searchkick_index.should_index?(self) }"
        f.puts "  end"
        f.puts ""
        f.puts "  class_methods do"
        f.puts "    # Define which fields to search by prefix (override in each model)"
        f.puts "    def searchkick_word_start_fields"
        f.puts "      []"
        f.puts "    end"
        f.puts ""
        f.puts "    # Define which fields to search by infix (override in each model)"
        f.puts "    def searchkick_word_middle_fields"
        f.puts "      []"
        f.puts "    end"
        f.puts ""
        f.puts "    # Define which text fields to search by prefix (override in each model)"
        f.puts "    def searchkick_text_start_fields"
        f.puts "      []"
        f.puts "    end"
        f.puts ""
        f.puts "    # Define which text fields to search by infix (override in each model)"
        f.puts "    def searchkick_text_middle_fields"
        f.puts "      []"
        f.puts "    end"
        f.puts ""
        f.puts "    # Define which fields to highlight in search results (override in each model)"
        f.puts "    def searchkick_highlight_fields"
        f.puts "      []"
        f.puts "    end"
        f.puts ""
        f.puts "    # Search method with pagination and sorting"
        f.puts "    def search_with_options(query, options = {})"
        f.puts "      search_options = {"
        f.puts "        fields: searchkick_word_start_fields + searchkick_word_middle_fields +"
        f.puts "                searchkick_text_start_fields + searchkick_text_middle_fields,"
        f.puts "        match: :word_start,"
        f.puts "        misspellings: { below: 5 },"
        f.puts "        highlight: { fields: searchkick_highlight_fields }"
        f.puts "      }"
        f.puts ""
        f.puts "      # Add pagination if provided"
        f.puts "      if options[:page] && options[:per_page]"
        f.puts "        search_options[:page] = options[:page]"
        f.puts "        search_options[:per_page] = options[:per_page]"
        f.puts "      end"
        f.puts ""
        f.puts "      # Add sorting if provided"
        f.puts "      if options[:sort]"
        f.puts "        field, direction = options[:sort].split(':')"
        f.puts "        search_options[:order] = { field => direction || :asc }"
        f.puts "      end"
        f.puts ""
        f.puts "      # Execute search"
        f.puts "      search(query, search_options)"
        f.puts "    end"
        f.puts "  end"
        f.puts "end"
      end
      
      # Add environment variable instructions to README
      update_readme_with_env_vars("MEILISEARCH_HOST", "URL for your MeiliSearch instance (default: http://localhost:7700)")
      update_readme_with_env_vars("MEILISEARCH_API_KEY", "API key for your MeiliSearch instance")
      
      puts "MeiliSearch configured successfully"
    end
    
    def setup_api_initializers
      # Create initializers directory if it doesn't exist
      FileUtils.mkdir_p "#{@rails_all_path}/config/initializers"
      
      # Create Pagy initializer
      setup_pagy_initializer
      
      # Create Rack CORS initializer
      setup_rack_cors_initializer
    end
    
    def setup_pagy_initializer
      pagy_initializer_path = "#{@rails_all_path}/config/initializers/pagy.rb"
      
      # Skip if the file already exists
      return if File.exist?(pagy_initializer_path)
      
      File.open(pagy_initializer_path, 'w') do |f|
        f.puts "# Pagy initializer"
        f.puts "require 'pagy/extras/overflow'"
        f.puts "require 'pagy/extras/headers'"
        f.puts "require 'pagy/extras/items'"
        f.puts "require 'pagy/extras/metadata'"
        f.puts ""
        f.puts "# Default options"
        f.puts "Pagy::DEFAULT[:items] = 20        # Items per page"
        f.puts "Pagy::DEFAULT[:max_items] = 100   # Max items per page"
        f.puts "Pagy::DEFAULT[:size] = [1, 4, 4, 1] # Navigation size"
        f.puts ""
        f.puts "# When the page number is too big, it defaults to the last available page"
        f.puts "Pagy::DEFAULT[:overflow] = :last_page"
        f.puts ""
        f.puts "# Add the pagy headers for API responses"
        f.puts "Rails.application.config.after_initialize do"
        f.puts "  if defined?(ActionController::API)"
        f.puts "    ActionController::API.include Pagy::Backend"
        f.puts "  end"
        f.puts "  ActionController::Base.include Pagy::Backend"
        f.puts "  ActionController::Base.include Pagy::Headers"
        f.puts "end"
      end
      
      # Add Pagy helper to application controller
      application_controller_path = "#{@rails_all_path}/app/controllers/application_controller.rb"
      
      if File.exist?(application_controller_path)
        content = File.read(application_controller_path)
        
        unless content.include?('include Pagy::Backend')
          updated_content = content.gsub(
            /class ApplicationController < ActionController::Base/,
            "class ApplicationController < ActionController::Base\n  include Pagy::Backend"
          )
          
          File.write(application_controller_path, updated_content)
        end
      end
    end
    
    def setup_rack_cors_initializer
      cors_initializer_path = "#{@rails_all_path}/config/initializers/cors.rb"
      
      # Skip if the file already exists
      return if File.exist?(cors_initializer_path)
      
      File.open(cors_initializer_path, 'w') do |f|
        f.puts "# Be sure to restart your server when you modify this file."
        f.puts ""
        f.puts "# Avoid CORS issues when API is called from the frontend app."
        f.puts "# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests."
        f.puts ""
        f.puts "# Read more: https://github.com/cyu/rack-cors"
        f.puts ""
        f.puts "Rails.application.config.middleware.insert_before 0, Rack::Cors do"
        f.puts "  allow do"
        f.puts "    origins ENV.fetch('CORS_ORIGINS', '*')"
        f.puts ""
        f.puts "    resource '*',"
        f.puts "      headers: :any,"
        f.puts "      methods: [:get, :post, :put, :patch, :delete, :options, :head],"
        f.puts "      credentials: false"
        f.puts "  end"
        f.puts "end"
      end
    end
    
    def setup_css_framework
      return unless @configuration&.css_framework
      
      FileUtils.chdir @rails_all_path do
        case @configuration.css_framework
        when :bootstrap
          setup_bootstrap
        when :tailwind
          setup_tailwind
        end
      end
    end
    
    def setup_bootstrap
      # Add Bootstrap gems
      File.open("Gemfile", "a") do |f|
        f.puts "\n# Bootstrap"
        f.puts "gem 'bootstrap', '~> 5.2.0'"
        f.puts "gem 'jquery-rails'"
      end
      
      system "bundle install"
      
      # Create or update application.scss
      FileUtils.mkdir_p "app/assets/stylesheets" unless Dir.exist?("app/assets/stylesheets")
      
      # Rename application.css to application.scss if it exists
      if File.exist?("app/assets/stylesheets/application.css")
        FileUtils.mv("app/assets/stylesheets/application.css", "app/assets/stylesheets/application.scss")
      end
      
      # Add Bootstrap imports
      File.open("app/assets/stylesheets/application.scss", "a") do |f|
        f.puts "\n// Bootstrap"
        f.puts "@import 'bootstrap';"
      end
      
      # Add Bootstrap JavaScript
      File.open("app/javascript/packs/application.js", "a") do |f|
        f.puts "\n// Bootstrap"
        f.puts "import 'bootstrap'"
      end
      
      puts "Bootstrap installed successfully"
    end
    
    def setup_tailwind
      # Install Tailwind CSS
      system "yarn add tailwindcss postcss autoprefixer"
      
      # Create Tailwind config files
      system "npx tailwindcss init"
      
      # Create postcss.config.js
      File.open("postcss.config.js", "w") do |f|
        f.puts "module.exports = {"
        f.puts "  plugins: ["
        f.puts "    require('tailwindcss'),"
        f.puts "    require('autoprefixer'),"
        f.puts "  ]"
        f.puts "}"
      end
      
      # Update application.css
      FileUtils.mkdir_p "app/assets/stylesheets" unless Dir.exist?("app/assets/stylesheets")
      
      File.open("app/assets/stylesheets/application.css", "w") do |f|
        f.puts "/*"
        f.puts " * This is a manifest file that'll be compiled into application.css, which will include all the files"
        f.puts " * listed below."
        f.puts " *"
        f.puts "*= require_tree ."
        f.puts "*= require_self"
        f.puts " */"
        f.puts "@import 'tailwindcss/base';"
        f.puts "@import 'tailwindcss/components';"
        f.puts "@import 'tailwindcss/utilities';"
      end
      
      # Update tailwind.config.js to include your application's paths
      tailwind_config = File.read("tailwind.config.js")
      updated_config = tailwind_config.gsub(
        "content: [],", 
        "content: ['./app/views/**/*.html.erb', './app/helpers/**/*.rb', './app/javascript/**/*.js'],"
      )
      File.write("tailwind.config.js", updated_config)
      
      puts "Tailwind CSS installed successfully"
    end
    
    def setup_form_builder
      return unless @configuration&.form_builder
      
      FileUtils.chdir @rails_all_path do
        case @configuration.form_builder
        when :simple_form
          setup_simple_form
        when :formtastic
          setup_formtastic
        end
        
        # Update form templates based on the chosen form builder
        update_form_templates
      end
    end
    
    def setup_simple_form
      # Add Simple Form gem if not already added
      unless @configuration.gems.any? { |g| g[:name] == 'simple_form' }
        File.open("Gemfile", "a") do |f|
          f.puts "\n# Simple Form"
          f.puts "gem 'simple_form'"
        end
        system "bundle install"
      end
      
      # Install Simple Form
      if @configuration.css_framework == :bootstrap
        system "rails generate simple_form:install --bootstrap"
      else
        system "rails generate simple_form:install"
      end
      
      puts "Simple Form installed successfully"
    end
    
    def setup_formtastic
      # Add Formtastic gem if not already added
      unless @configuration.gems.any? { |g| g[:name] == 'formtastic' }
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
    
    def setup_features
      return unless @configuration&.features&.any?
      
      FileUtils.chdir @rails_all_path do
        # Handle authentication
        if @configuration.features[:authentication]
          setup_authentication
        end
        
        # Handle file uploads
        if @configuration.features[:file_upload]
          setup_file_upload
        end
        
        # Handle background jobs
        if @configuration.features[:background_jobs]
          setup_background_jobs
        end
        
        # Handle vector database if configured
        if @configuration.vector_db
          setup_vector_database
        end
      end
    end
    
    def setup_authentication
      auth_config = @configuration.features[:authentication]
      auth_type = auth_config[:provider] || :rodauth
      
      case auth_type
      when :rodauth
        setup_rodauth(auth_config)
      when :devise
        setup_devise(auth_config)
      end
    end
    
    def setup_rodauth(auth_config)
      # Add Rodauth gem if not already added
      unless @configuration.gems.any? { |g| g[:name] == 'rodauth-rails' }
        File.open("Gemfile", "a") do |f|
          f.puts "\n# Rodauth for authentication"
          f.puts "gem 'rodauth-rails'"
          
          # Add WebAuthn gem if passkeys are enabled
          if auth_config[:passkeys]
            f.puts "gem 'webauthn'"
          end
        end
        system "bundle install"
      end
      
      # Install Rodauth
      system "rails generate rodauth:install"
      
      # Configure Rodauth with selected features
      configure_rodauth(auth_config)
    end
    
    def setup_devise(auth_config)
      # Add Devise gem if not already added
      unless @configuration.gems.any? { |g| g[:name] == 'devise' }
        File.open("Gemfile", "a") do |f|
          f.puts "\n# Devise for authentication"
          f.puts "gem 'devise'"
          
          # Add WebAuthn gems if passkeys are enabled
          if auth_config[:passkeys]
            f.puts "gem 'devise-passkeys'"
            f.puts "gem 'webauthn'"
          end
        end
        system "bundle install"
      end
      
      # Install Devise
      system "rails generate devise:install"
      
      # Generate User model if requested
      if auth_config[:generate_user]
        system "rails generate devise User"
      end
      
      # Configure Devise with passkeys if enabled
      if auth_config[:passkeys]
        configure_devise_passkeys(auth_config)
      end
    end
    
    def configure_rodauth(auth_config)
      # Find the Rodauth initializer
      rodauth_initializer = "#{@rails_all_path}/config/initializers/rodauth.rb"
      
      if File.exist?(rodauth_initializer)
        content = File.read(rodauth_initializer)
        
        # Add WebAuthn features if passkeys are enabled
        if auth_config[:passkeys]
          # Add webauthn feature to the features list
          content.gsub!(/enable :.*?$/) do |match|
            features = match.split(':').last.strip
            features_list = features.split(',').map(&:strip)
            features_list << 'webauthn' unless features_list.include?('webauthn')
            features_list << 'webauthn_login' unless features_list.include?('webauthn_login')
            "enable :#{features_list.join(', ')}"
          end
          
          # Add WebAuthn configuration
          passkey_options = auth_config[:passkey_options] || {}
          rp_name = passkey_options[:rp_name] || "Rails Application"
          rp_id = passkey_options[:rp_id] || "localhost"
          origin = passkey_options[:origin] || "http://localhost:3000"
          
          webauthn_config = <<~RUBY
            
            # WebAuthn (Passkeys) Configuration
            webauthn_rp_name "#{rp_name}"
            webauthn_rp_id "#{rp_id}"
            webauthn_origin "#{origin}"
            webauthn_algorithms ["ES256", "RS256"]
            webauthn_user_verification "preferred"
          RUBY
          
          # Add WebAuthn configuration before the closing 'end'
          content.gsub!(/^(\s*)end(\s*)$/) do |match|
            indent = $1
            newline = $2
            "#{indent}#{webauthn_config.gsub(/^/, indent)}#{indent}end#{newline}"
          end
          
          # Write the updated content back to the file
          File.write(rodauth_initializer, content)
          
          # Create WebAuthn routes
          add_webauthn_routes_for_rodauth
          
          # Create WebAuthn views
          create_webauthn_views_for_rodauth
          
          puts "Rodauth WebAuthn (Passkeys) configured successfully"
        end
      end
    end
    
    def configure_devise_passkeys(auth_config)
      # Add Devise Passkeys initializer
      passkey_options = auth_config[:passkey_options] || {}
      rp_name = passkey_options[:rp_name] || "Rails Application"
      rp_id = passkey_options[:rp_id] || "localhost"
      origin = passkey_options[:origin] || "http://localhost:3000"
      
      FileUtils.mkdir_p "#{@rails_all_path}/config/initializers"
      File.open("#{@rails_all_path}/config/initializers/devise_passkeys.rb", "w") do |f|
        f.puts "# frozen_string_literal: true"
        f.puts ""
        f.puts "Devise::Passkeys.setup do |config|"
        f.puts "  # The name for your application that will be shown during WebAuthn registration"
        f.puts "  config.rp_name = \"#{rp_name}\""
        f.puts ""
        f.puts "  # The Relying Party ID, which defaults to your domain name"
        f.puts "  config.rp_id = \"#{rp_id}\""
        f.puts ""
        f.puts "  # The origins that are allowed to authenticate with your application"
        f.puts "  config.origin = \"#{origin}\""
        f.puts ""
        f.puts "  # The algorithms to use for WebAuthn authentication"
        f.puts "  config.algorithms = [\"ES256\", \"RS256\"]"
        f.puts ""
        f.puts "  # User verification preference"
        f.puts "  config.user_verification = \"preferred\""
        f.puts "end"
      end
      
      # Update User model to include passkeys
      update_user_model_for_passkeys
      
      # Add passkeys routes
      add_passkeys_routes_for_devise
      
      # Create passkeys views
      create_passkeys_views_for_devise
      
      puts "Devise Passkeys configured successfully"
    end
    
    def update_user_model_for_passkeys
      user_model_path = "#{@rails_all_path}/app/models/user.rb"
      
      if File.exist?(user_model_path)
        content = File.read(user_model_path)
        
        # Add passkeys module to devise list if not already present
        unless content.include?("devise :passkeys") || content.include?(":passkeys")
          content.gsub!(/devise(.*?)$/) do |match|
            if match.include?(":")
              # Add passkeys to the list of devise modules
              "devise#{$1}, :passkeys"
            else
              # No modules specified yet
              "devise :passkeys#{$1}"
            end
          end
          
          # Write the updated content back to the file
          File.write(user_model_path, content)
        end
      end
    end
    
    def add_passkeys_routes_for_devise
      routes_path = "#{@rails_all_path}/config/routes.rb"
      
      if File.exist?(routes_path)
        content = File.read(routes_path)
        
        # Add passkeys routes if not already present
        unless content.include?("devise_passkeys")
          devise_for_line = content.match(/devise_for.*/)
          
          if devise_for_line
            # Replace the devise_for line with one that includes passkeys controllers
            updated_line = devise_for_line[0].gsub(/devise_for :users/) do
              "devise_for :users, controllers: { passkeys: 'users/passkeys' }"
            end
            
            content.gsub!(devise_for_line[0], updated_line)
          else
            # Add devise_for with passkeys controllers
            content.gsub!(/Rails\.application\.routes\.draw do\s*\n/) do |match|
              "#{match}  devise_for :users, controllers: { passkeys: 'users/passkeys' }\n"
            end
          end
          
          # Write the updated content back to the file
          File.write(routes_path, content)
        end
      end
    end
    
    def add_webauthn_routes_for_rodauth
      routes_path = "#{@rails_all_path}/config/routes.rb"
      
      if File.exist?(routes_path)
        content = File.read(routes_path)
        
        # Add WebAuthn routes if not already present
        unless content.include?("webauthn")
          webauthn_routes = <<~RUBY
            
            # WebAuthn (Passkeys) routes
            resources :webauthn_credentials, only: [:new, :create, :destroy]
            get 'webauthn_login', to: 'rodauth#webauthn_login'
            post 'webauthn_login', to: 'rodauth#webauthn_login'
            get 'webauthn_setup', to: 'rodauth#webauthn_setup'
            post 'webauthn_setup', to: 'rodauth#webauthn_setup'
          RUBY
          
          # Add WebAuthn routes inside the routes block
          content.gsub!(/Rails\.application\.routes\.draw do\s*\n/) do |match|
            "#{match}#{webauthn_routes}"
          end
          
          # Write the updated content back to the file
          File.write(routes_path, content)
        end
      end
    end
    
    def create_webauthn_views_for_rodauth
      views_path = "#{@rails_all_path}/app/views/rodauth"
      FileUtils.mkdir_p views_path
      
      # Create WebAuthn setup view
      File.open("#{views_path}/webauthn_setup.html.erb", "w") do |f|
        f.puts "<h1>Setup WebAuthn (Passkey)</h1>"
        f.puts ""
        f.puts "<% if rodauth.webauthn_setup_phase1? %>"
        f.puts "  <%= form_with url: rodauth.webauthn_setup_path, method: :post, data: { turbo: false } do |form| %>"
        f.puts "    <div class=\"form-group\">"
        f.puts "      <%= form.label :webauthn_setup_name, \"Authenticator Name\" %>"
        f.puts "      <%= form.text_field :webauthn_setup_name, value: params[:webauthn_setup_name], class: 'form-control', required: true %>"
        f.puts "    </div>"
        f.puts "    <div class=\"form-group\">"
        f.puts "      <%= form.submit \"Setup WebAuthn\", class: 'btn btn-primary' %>"
        f.puts "    </div>"
        f.puts "  <% end %>"
        f.puts "<% else %>"
        f.puts "  <div id=\"webauthn-setup-container\">"
        f.puts "    <p>Please follow your browser's instructions to register your authenticator.</p>"
        f.puts "  </div>"
        f.puts ""
        f.puts "  <script>"
        f.puts "    document.addEventListener('DOMContentLoaded', function() {"
        f.puts "      const credential = <%= raw rodauth.webauthn_setup_options_json %>;"
        f.puts "      credential.publicKey.challenge = new Uint8Array(<%= raw rodauth.webauthn_setup_challenge_json %>);"
        f.puts "      credential.publicKey.user.id = new Uint8Array(<%= raw rodauth.webauthn_setup_user_id_json %>);"
        f.puts "      credential.publicKey.excludeCredentials = credential.publicKey.excludeCredentials.map(function(c) {"
        f.puts "        c.id = new Uint8Array(c.id);"
        f.puts "        return c;"
        f.puts "      });"
        f.puts ""
        f.puts "      navigator.credentials.create(credential)"
        f.puts "        .then(function(credential) {"
        f.puts "          const form = document.createElement('form');"
        f.puts "          form.method = 'POST';"
        f.puts "          form.action = '<%= rodauth.webauthn_setup_path %>';"
        f.puts ""
        f.puts "          const clientDataJSON = document.createElement('input');"
        f.puts "          clientDataJSON.name = 'client_data_json';"
        f.puts "          clientDataJSON.type = 'hidden';"
        f.puts "          clientDataJSON.value = arrayToBase64(new Uint8Array(credential.response.clientDataJSON));"
        f.puts "          form.appendChild(clientDataJSON);"
        f.puts ""
        f.puts "          const attestationObject = document.createElement('input');"
        f.puts "          attestationObject.name = 'attestation_object';"
        f.puts "          attestationObject.type = 'hidden';"
        f.puts "          attestationObject.value = arrayToBase64(new Uint8Array(credential.response.attestationObject));"
        f.puts "          form.appendChild(attestationObject);"
        f.puts ""
        f.puts "          document.body.appendChild(form);"
        f.puts "          form.submit();"
        f.puts "        })"
        f.puts "        .catch(function(error) {"
        f.puts "          console.error('WebAuthn setup error:', error);"
        f.puts "          alert('WebAuthn setup failed: ' + error);"
        f.puts "          window.location.href = '<%= rodauth.webauthn_setup_path %>';"
        f.puts "        });"
        f.puts "    });"
        f.puts ""
        f.puts "    function arrayToBase64(array) {"
        f.puts "      return btoa(String.fromCharCode.apply(null, array));"
        f.puts "    }"
        f.puts "  </script>"
        f.puts "<% end %>"
      end
      
      # Create WebAuthn login view
      File.open("#{views_path}/webauthn_login.html.erb", "w") do |f|
        f.puts "<h1>Login with WebAuthn (Passkey)</h1>"
        f.puts ""
        f.puts "<% if rodauth.webauthn_login_phase1? %>"
        f.puts "  <%= form_with url: rodauth.webauthn_login_path, method: :post, data: { turbo: false } do |form| %>"
        f.puts "    <div class=\"form-group\">"
        f.puts "      <%= form.label :login, \"Username or Email\" %>"
        f.puts "      <%= form.text_field :login, value: params[:login], class: 'form-control', required: true %>"
        f.puts "    </div>"
        f.puts "    <div class=\"form-group\">"
        f.puts "      <%= form.submit \"Login with WebAuthn\", class: 'btn btn-primary' %>"
        f.puts "    </div>"
        f.puts "  <% end %>"
        f.puts "<% else %>"
        f.puts "  <div id=\"webauthn-login-container\">"
        f.puts "    <p>Please follow your browser's instructions to authenticate with your passkey.</p>"
        f.puts "  </div>"
        f.puts ""
        f.puts "  <script>"
        f.puts "    document.addEventListener('DOMContentLoaded', function() {"
        f.puts "      const credential = <%= raw rodauth.webauthn_login_options_json %>;"
        f.puts "      credential.publicKey.challenge = new Uint8Array(<%= raw rodauth.webauthn_login_challenge_json %>);"
        f.puts "      credential.publicKey.allowCredentials = credential.publicKey.allowCredentials.map(function(c) {"
        f.puts "        c.id = new Uint8Array(c.id);"
        f.puts "        return c;"
        f.puts "      });"
        f.puts ""
        f.puts "      navigator.credentials.get(credential)"
        f.puts "        .then(function(credential) {"
        f.puts "          const form = document.createElement('form');"
        f.puts "          form.method = 'POST';"
        f.puts "          form.action = '<%= rodauth.webauthn_login_path %>';"
        f.puts ""
        f.puts "          const clientDataJSON = document.createElement('input');"
        f.puts "          clientDataJSON.name = 'client_data_json';"
        f.puts "          clientDataJSON.type = 'hidden';"
        f.puts "          clientDataJSON.value = arrayToBase64(new Uint8Array(credential.response.clientDataJSON));"
        f.puts "          form.appendChild(clientDataJSON);"
        f.puts ""
        f.puts "          const authenticatorData = document.createElement('input');"
        f.puts "          authenticatorData.name = 'authenticator_data';"
        f.puts "          authenticatorData.type = 'hidden';"
        f.puts "          authenticatorData.value = arrayToBase64(new Uint8Array(credential.response.authenticatorData));"
        f.puts "          form.appendChild(authenticatorData);"
        f.puts ""
        f.puts "          const signature = document.createElement('input');"
        f.puts "          signature.name = 'signature';"
        f.puts "          signature.type = 'hidden';"
        f.puts "          signature.value = arrayToBase64(new Uint8Array(credential.response.signature));"
        f.puts "          form.appendChild(signature);"
        f.puts ""
        f.puts "          const credentialId = document.createElement('input');"
        f.puts "          credentialId.name = 'credential_id';"
        f.puts "          credentialId.type = 'hidden';"
        f.puts "          credentialId.value = credential.id;"
        f.puts "          form.appendChild(credentialId);"
        f.puts ""
        f.puts "          document.body.appendChild(form);"
        f.puts "          form.submit();"
        f.puts "        })"
        f.puts "        .catch(function(error) {"
        f.puts "          console.error('WebAuthn login error:', error);"
        f.puts "          alert('WebAuthn login failed: ' + error);"
        f.puts "          window.location.href = '<%= rodauth.webauthn_login_path %>';"
        f.puts "        });"
        f.puts "    });"
        f.puts ""
        f.puts "    function arrayToBase64(array) {"
        f.puts "      return btoa(String.fromCharCode.apply(null, array));"
        f.puts "    }"
        f.puts "  </script>"
        f.puts "<% end %>"
      end
    end
    
    def create_passkeys_views_for_devise
      # Create controllers directory
      controllers_path = "#{@rails_all_path}/app/controllers/users"
      FileUtils.mkdir_p controllers_path
      
      # Create passkeys controller
      File.open("#{controllers_path}/passkeys_controller.rb", "w") do |f|
        f.puts "# frozen_string_literal: true"
        f.puts ""
        f.puts "class Users::PasskeysController < Devise::PasskeysController"
        f.puts "  # You can override methods here if needed"
        f.puts "end"
      end
      
      # Create views directory
      views_path = "#{@rails_all_path}/app/views/users/passkeys"
      FileUtils.mkdir_p views_path
      
      # Create new passkey view
      File.open("#{views_path}/new.html.erb", "w") do |f|
        f.puts "<h2>Register a new passkey</h2>"
        f.puts ""
        f.puts "<div id=\"passkey-registration-container\">"
        f.puts "  <p>Please provide a name for this passkey:</p>"
        f.puts "  <%= form_with url: passkeys_path, method: :post, data: { turbo: false } do |form| %>"
        f.puts "    <div class=\"form-group\">"
        f.puts "      <%= form.label :name, \"Passkey Name\" %>"
        f.puts "      <%= form.text_field :name, class: 'form-control', required: true %>"
        f.puts "    </div>"
        f.puts "    <div class=\"form-group\">"
        f.puts "      <%= form.submit \"Register Passkey\", class: 'btn btn-primary', id: 'register-passkey-button' %>"
        f.puts "    </div>"
        f.puts "  <% end %>"
        f.puts "</div>"
        f.puts ""
        f.puts "<div id=\"passkey-registration-status\" style=\"display: none;\">"
        f.puts "  <p>Please follow your browser's instructions to register your passkey.</p>"
        f.puts "</div>"
        f.puts ""
        f.puts "<script>"
        f.puts "  document.addEventListener('DOMContentLoaded', function() {"
        f.puts "    const registerButton = document.getElementById('register-passkey-button');"
        f.puts "    if (registerButton) {"
        f.puts "      registerButton.addEventListener('click', function(event) {"
        f.puts "        event.preventDefault();"
        f.puts "        const nameField = document.querySelector('input[name=\"name\"]');"
        f.puts "        if (!nameField.value) {"
        f.puts "          alert('Please provide a name for this passkey');"
        f.puts "          return;"
        f.puts "        }"
        f.puts ""
        f.puts "        document.getElementById('passkey-registration-container').style.display = 'none';"
        f.puts "        document.getElementById('passkey-registration-status').style.display = 'block';"
        f.puts ""
        f.puts "        fetch('/passkeys/options', {"
        f.puts "          method: 'POST',"
        f.puts "          headers: {"
        f.puts "            'Content-Type': 'application/json',"
        f.puts "            'X-CSRF-Token': document.querySelector('meta[name=\"csrf-token\"]').content"
        f.puts "          },"
        f.puts "          body: JSON.stringify({ name: nameField.value })"
        f.puts "        })"
        f.puts "        .then(response => response.json())"
        f.puts "        .then(data => {"
        f.puts "          // Convert base64 strings to ArrayBuffer"
        f.puts "          data.publicKey.challenge = base64ToArrayBuffer(data.publicKey.challenge);"
        f.puts "          data.publicKey.user.id = base64ToArrayBuffer(data.publicKey.user.id);"
        f.puts ""
        f.puts "          if (data.publicKey.excludeCredentials) {"
        f.puts "            data.publicKey.excludeCredentials = data.publicKey.excludeCredentials.map(credential => {"
        f.puts "              return {"
        f.puts "                ...credential,"
        f.puts "                id: base64ToArrayBuffer(credential.id)"
        f.puts "              };"
        f.puts "            });"
        f.puts "          }"
        f.puts ""
        f.puts "          return navigator.credentials.create(data);"
        f.puts "        })"
        f.puts "        .then(credential => {"
        f.puts "          const credentialResponse = {"
        f.puts "            id: credential.id,"
        f.puts "            rawId: arrayBufferToBase64(credential.rawId),"
        f.puts "            type: credential.type,"
        f.puts "            response: {"
        f.puts "              clientDataJSON: arrayBufferToBase64(credential.response.clientDataJSON),"
        f.puts "              attestationObject: arrayBufferToBase64(credential.response.attestationObject)"
        f.puts "            }"
        f.puts "          };"
        f.puts ""
        f.puts "          return fetch('/passkeys', {"
        f.puts "            method: 'POST',"
        f.puts "            headers: {"
        f.puts "              'Content-Type': 'application/json',"
        f.puts "              'X-CSRF-Token': document.querySelector('meta[name=\"csrf-token\"]').content"
        f.puts "            },"
        f.puts "            body: JSON.stringify({"
        f.puts "              credential: credentialResponse,"
        f.puts "              name: nameField.value"
        f.puts "            })"
        f.puts "          });"
        f.puts "        })"
        f.puts "        .then(response => {"
        f.puts "          if (response.ok) {"
        f.puts "            window.location.href = '/passkeys';"
        f.puts "          } else {"
        f.puts "            throw new Error('Failed to register passkey');"
        f.puts "          }"
        f.puts "        })"
        f.puts "        .catch(error => {"
        f.puts "          console.error('Error:', error);"
        f.puts "          alert('Failed to register passkey: ' + error.message);"
        f.puts "          document.getElementById('passkey-registration-container').style.display = 'block';"
        f.puts "          document.getElementById('passkey-registration-status').style.display = 'none';"
        f.puts "        });"
        f.puts "      });"
        f.puts "    }"
        f.puts "  });"
        f.puts ""
        f.puts "  function base64ToArrayBuffer(base64) {"
        f.puts "    const binaryString = window.atob(base64);"
        f.puts "    const bytes = new Uint8Array(binaryString.length);"
        f.puts "    for (let i = 0; i < binaryString.length; i++) {"
        f.puts "      bytes[i] = binaryString.charCodeAt(i);"
        f.puts "    }"
        f.puts "    return bytes.buffer;"
        f.puts "  }"
        f.puts ""
        f.puts "  function arrayBufferToBase64(buffer) {"
        f.puts "    const bytes = new Uint8Array(buffer);"
        f.puts "    let binary = '';"
        f.puts "    for (let i = 0; i < bytes.byteLength; i++) {"
        f.puts "      binary += String.fromCharCode(bytes[i]);"
        f.puts "    }"
        f.puts "    return window.btoa(binary);"
        f.puts "  }"
        f.puts "</script>"
      end
      
      # Create index view for passkeys
      File.open("#{views_path}/index.html.erb", "w") do |f|
        f.puts "<h2>Your Passkeys</h2>"
        f.puts ""
        f.puts "<% if @passkeys.any? %>"
        f.puts "  <table class=\"table\">"
        f.puts "    <thead>"
        f.puts "      <tr>"
        f.puts "        <th>Name</th>"
        f.puts "        <th>Created</th>"
        f.puts "        <th>Last used</th>"
        f.puts "        <th>Actions</th>"
        f.puts "      </tr>"
        f.puts "    </thead>"
        f.puts "    <tbody>"
        f.puts "      <% @passkeys.each do |passkey| %>"
        f.puts "        <tr>"
        f.puts "          <td><%= passkey.name %></td>"
        f.puts "          <td><%= passkey.created_at.strftime('%B %d, %Y') %></td>"
        f.puts "          <td><%= passkey.last_used_at ? passkey.last_used_at.strftime('%B %d, %Y') : 'Never' %></td>"
        f.puts "          <td>"
        f.puts "            <%= button_to 'Delete', passkey_path(passkey), method: :delete, data: { confirm: 'Are you sure?' }, class: 'btn btn-sm btn-danger' %>"
        f.puts "          </td>"
        f.puts "        </tr>"
        f.puts "      <% end %>"
        f.puts "    </tbody>"
        f.puts "  </table>"
        f.puts "<% else %>"
        f.puts "  <p>You don't have any passkeys yet.</p>"
        f.puts "<% end %>"
        f.puts ""
        f.puts "<div class=\"mt-4\">"
        f.puts "  <%= link_to 'Register a new passkey', new_passkey_path, class: 'btn btn-primary' %>"
        f.puts "</div>"
      end
    end
    
    def setup_file_upload
      upload_type = @configuration.features[:file_upload][:provider] || :active_storage
      
      case upload_type
      when :active_storage
        system "rails active_storage:install"
        system "rails db:migrate"
      when :shrine
        # Setup shrine configuration
      end
    end
    
    def setup_background_jobs
      job_type = @configuration.features[:background_jobs][:provider] || :sidekiq
      
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
    
    def setup_monitoring
      return unless @configuration&.monitoring&.any?
      
      FileUtils.chdir @rails_all_path do
        # Create initializers directory if it doesn't exist
        FileUtils.mkdir_p "config/initializers"
        
        # Install each monitoring tool
        @configuration.monitoring.each do |tool|
          case tool
          when :new_relic
            setup_new_relic
          when :datadog
            setup_datadog
          when :sentry
            setup_sentry
          end
        end
      end
    end
    
    def setup_new_relic
      # Add New Relic gem if not already added
      unless @configuration.gems.any? { |g| g[:name] == 'newrelic_rpm' }
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
    
    def setup_datadog
      # Add Datadog gems if not already added
      datadog_gems = ['ddtrace', 'dogstatsd-ruby']
      datadog_gems.each do |gem_name|
        unless @configuration.gems.any? { |g| g[:name] == gem_name }
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
    
    def setup_sentry
      # Add Sentry gem if not already added
      unless @configuration.gems.any? { |g| g[:name] == 'sentry-ruby' || g[:name] == 'sentry-rails' }
        File.open("Gemfile", "a") do |f|
          f.puts "\n# Sentry"
          f.puts "gem 'sentry-ruby'"
          f.puts "gem 'sentry-rails'"
          f.puts "gem 'sentry-sidekiq'" if @configuration.features[:background_jobs]
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
    
    def load_configuration_from_yaml(yaml_path)
      require 'yaml'
      require_relative '../../configuration/application_configuration'
      
      log_info("Loading configuration from YAML file: #{yaml_path}")
      
      begin
        yaml_content = YAML.load_file(yaml_path)
        config = Tenant::Configuration::ApplicationConfiguration.new
        
        # Process configuration sections
        process_basic_configuration(config, yaml_content)
        process_database_configuration(config, yaml_content)
        process_search_engine_configuration(config, yaml_content)
        process_vector_db_configuration(config, yaml_content)
        process_gems_configuration(config, yaml_content)
        process_features_configuration(config, yaml_content)
        process_monitoring_configuration(config, yaml_content)
        
        @configuration = config
        log_info("Configuration loaded successfully")
        return config
      rescue => e
        log_error("Failed to load configuration from YAML: #{e.message}")
        raise e
      end
    end
    
    def process_basic_configuration(config, yaml_content)
      # Set basic configuration options
      config.frontend = yaml_content['frontend']&.to_sym if yaml_content['frontend']
      config.css_framework = yaml_content['css_framework']&.to_sym if yaml_content['css_framework']
      config.controller_inheritance = yaml_content['controller_inheritance'] unless yaml_content['controller_inheritance'].nil?
      config.form_builder = yaml_content['form_builder']&.to_sym if yaml_content['form_builder']
    end
    
    def process_database_configuration(config, yaml_content)
      # Set database configuration
      if yaml_content['database']
        db_type = yaml_content['database'].to_sym
        db_options = yaml_content['database_options'] || {}
        config.set_database(db_type, db_options)
      end
    end
    
    def process_search_engine_configuration(config, yaml_content)
      # Set search engine configuration
      if yaml_content['search_engine']
        search_engine = yaml_content['search_engine'].to_sym
        search_engine_options = yaml_content['search_engine_options'] || {}
        config.enable_search_engine(search_engine, search_engine_options)
      end
    end
    
    def process_vector_db_configuration(config, yaml_content)
      # Set vector database configuration
      if yaml_content['vector_db']
        vector_db = yaml_content['vector_db'].to_sym
        vector_db_options = yaml_content['vector_db_options'] || {}
        config.enable_vector_db(vector_db, vector_db_options)
      end
      
      # Set embedding provider configuration
      if yaml_content['embedding_provider']
        provider = yaml_content['embedding_provider'].to_sym
        provider_options = yaml_content['embedding_provider_options'] || {}
        config.set_embedding_provider(provider, provider_options)
      end
    end
    
    def process_gems_configuration(config, yaml_content)
      # Add gems
      if yaml_content['gems']&.is_a?(Array)
        yaml_content['gems'].each do |gem_info|
          name = gem_info['name']
          version = gem_info['version']
          options = gem_info['options'] || {}
          
          config.add_gem(name, version, options) if name
        end
      end
    end
    
    def process_features_configuration(config, yaml_content)
      # Enable features
      if yaml_content['features']&.is_a?(Hash)
        # Authentication
        if yaml_content['features']['authentication']
          auth_config = yaml_content['features']['authentication']
          provider = auth_config['provider']&.to_sym || :rodauth
          options = auth_config.except('provider') || {}
          
          config.enable_authentication(provider, options)
        end
        
        # File upload
        if yaml_content['features']['file_upload']
          upload_config = yaml_content['features']['file_upload']
          provider = upload_config['provider']&.to_sym || :active_storage
          options = upload_config.except('provider') || {}
          
          config.enable_file_upload(provider, options)
        end
        
        # Background jobs
        if yaml_content['features']['background_jobs']
          jobs_config = yaml_content['features']['background_jobs']
          provider = jobs_config['provider']&.to_sym || :sidekiq
          options = jobs_config.reject { |k, _| k == 'provider' }
          
          config.enable_background_jobs(provider, options)
        end
      end
    end
    
    def process_monitoring_configuration(config, yaml_content)
      # Set monitoring configuration
      if yaml_content['monitoring']&.is_a?(Hash)
        yaml_content['monitoring'].each do |tool, enabled|
          config.enable_monitoring(tool.to_sym) if enabled
        end
      end
    end
  end
end 