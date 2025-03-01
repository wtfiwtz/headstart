# require 'json'
require 'fileutils'
require 'erb'
require 'yaml'
require 'active_support/core_ext/string/inflections'
require_relative "./src/generators/base"
require_relative './src/generators/ruby'

ModelStruct = Struct.new(:name, :attributes, :associations)

module Tenant
  class Configuration
    attr_accessor :frontend, :gems, :features, :css_framework, :controller_inheritance, :form_builder, :monitoring, :template_engine
    
    def initialize
      @frontend = :mvc # Default to traditional MVC
      @gems = [] # List of gems to include
      @features = {} # Features to enable (e.g., authentication, file_upload)
      @css_framework = :bootstrap # Default to no CSS framework
      @controller_inheritance = true
      @form_builder = :default # Default Rails form builder (:simple_form, :formtastic)
      @monitoring = [] # List of monitoring tools to include (:new_relic, :datadog, :sentry)
      @template_engine = :erb # Default template engine (:erb, :slim, :haml)
    end
  end

  class Builder
    class << self
      def configuration
        @configuration ||= Configuration.new
      end
      
      def configure
        yield(configuration) if block_given?
      end

      def model(name, &_block)
        model_builder = ModelStruct.new
        model_builder.name = name
        model_builder.attributes = {}
        model_builder.associations = []
        yield(self, model_builder) if block_given?
        model_builder
      end

      def attributes(model, attrs)
        model.attributes = attrs
      end

      def has_one(model, assoc, attrs = {})
        model.associations << { kind: :has_one, name: assoc, attrs: attrs }
      end

      def has_many(model, assoc, attrs = {})
        model.associations << { kind: :has_many, name: assoc, attrs: attrs }
      end

      def belongs_to(model, assoc, attrs = {})
        model.associations << { kind: :belongs_to, name: assoc, attrs: attrs }
      end

      def has_and_belongs_to_many(model, assoc, attrs = {})
        model.associations << { kind: :has_and_belongs_to_many, name: assoc, attrs: attrs }
      end

      def has_many_through(model, assoc, through, attrs = {})
        attrs[:through] = through
        model.associations << { kind: :has_many, name: assoc, attrs: attrs }
      end

      def generator(kind = :ruby)
        case kind
        when :ruby then RubyGenerator.new
        when :express then ExpressGenerator.new
        else RubyGenerator.new
        end
      end
      
      def load_models_from_yaml(yaml_path)
        puts "Loading models from YAML file: #{yaml_path}"
        
        begin
          yaml_content = YAML.load_file(yaml_path)
          models_array = []
          
          yaml_content['models'].each do |model_name, model_data|
            model = ModelStruct.new
            model.name = model_name
            model.attributes = {}
            model.associations = []
            
            # Add attributes
            if model_data['attributes']
              model_data['attributes'].each do |attr_name, attr_type|
                model.attributes[attr_name.to_sym] = attr_type.to_sym
              end
            end
            
            # Add associations
            if model_data['associations']
              model_data['associations'].each do |assoc|
                association = {
                  kind: assoc['kind'].to_sym,
                  name: assoc['name'],
                  attrs: {}
                }
                
                # Convert association attributes
                if assoc['attrs']
                  assoc['attrs'].each do |key, value|
                    # Convert string keys to symbols
                    attr_key = key.to_sym
                    
                    # Handle boolean values correctly
                    attr_value = case value
                                when 'true'
                                  true
                                when 'false'
                                  false
                                else
                                  value
                                end
                    
                    # Convert to symbol if appropriate
                    if [:dependent, :through, :source, :as].include?(attr_key)
                      attr_value = attr_value.to_sym unless attr_value.nil?
                    end
                    
                    association[:attrs][attr_key] = attr_value
                  end
                end
                
                model.associations << association
              end
            end
            
            models_array << model
          end
          
          puts "Loaded #{models_array.size} models from YAML"
          return models_array
        rescue StandardError => e
          puts "Error loading models from YAML: #{e.message}"
          raise
        end
      end
      
      def build_from_yaml(yaml_path, generator_type = :ruby)
        # Load configuration from YAML
        yaml_content = YAML.load_file(yaml_path)
        
        # Configure the application
        configure do |config|
          # Set basic configuration
          config.frontend = yaml_content['frontend'].to_sym if yaml_content['frontend']
          config.css_framework = yaml_content['css_framework'].to_sym if yaml_content['css_framework']
          config.form_builder = yaml_content['form_builder'].to_sym if yaml_content['form_builder']
          config.template_engine = yaml_content['template_engine'].to_sym if yaml_content['template_engine']
          
          # Add gems
          if yaml_content['gems']&.is_a?(Array)
            yaml_content['gems'].each do |gem_info|
              if gem_info.is_a?(Hash)
                config.gems << gem_info.transform_keys(&:to_sym)
              else
                config.gems << {name: gem_info}
              end
            end
          end
          
          # Set monitoring tools
          if yaml_content['monitoring']&.is_a?(Array)
            config.monitoring = yaml_content['monitoring'].map(&:to_sym)
          end
          
          # Enable features
          if yaml_content['features']&.is_a?(Hash)
            yaml_content['features'].each do |feature_name, feature_config|
              if feature_config.is_a?(Hash)
                config.features[feature_name.to_sym] = feature_config.transform_keys(&:to_sym)
                
                # Convert nested values to symbols where appropriate
                if feature_config['provider']
                  config.features[feature_name.to_sym][:provider] = feature_config['provider'].to_sym
                end
              else
                config.features[feature_name.to_sym] = feature_config
              end
            end
          end
        end
        
        # Load models from YAML
        models = load_models_from_yaml(yaml_path)
        
        # Initialize and execute the appropriate generator
        generator(generator_type)
          .apply_configuration(configuration)
          .models(models)
          .execute
      end
    end
  end
end

# Example usage with YAML file:
# Tenant::Builder.build_from_yaml('models.yml', :ruby)

# Legacy example with DSL:
if __FILE__ == $0
  # Configure the application
  Tenant::Builder.configure do |config|
    config.frontend = :mvc  # :react, :vue = Use React, Vue.js frontend
    
    # Add gems
    config.gems << {name: 'rodauth-rails'}
    config.gems << {name: 'image_processing', version: '~> 1.2'}
    config.gems << {name: 'sidekiq'}

    # Choose CSS framework
    config.css_framework = :bootstrap  # or :tailwind
    
    # Use controller inheritance pattern
    config.controller_inheritance = true
    
    # Choose form builder
    config.form_builder = :simple_form  # or :formtastic or :default
    
    # Choose template engine
    config.template_engine = :slim  # or :haml or :erb (default)
    
    # Add monitoring tools
    config.monitoring = [:new_relic, :datadog, :sentry]
    
    # Enable features
    config.features[:authentication] = {
      provider: :rodauth,
      features: %w[login logout create_account verify_account_email reset_password otp]
    }
    
    config.features[:file_upload] = {
      provider: :active_storage
    }
    
    config.features[:background_jobs] = {
      provider: :sidekiq
    }
  end

  # Define models with complex relationships
  user = Tenant::Builder.model(:user) do |b, m|
    b.attributes m, {
      name: :string,
      email: :string,
      password: :string,
      active: :boolean,
      last_login_at: :datetime
    }
    b.has_many m, :accounts, dependent: :destroy
    b.has_many m, :posts, dependent: :nullify
    b.has_one m, :profile, dependent: :destroy
    b.has_many_through m, :comments, :posts
  end

  account = Tenant::Builder.model(:account) do |b, m|
    b.attributes m, {
      name: :string,
      number: :string,
      active: :boolean
    }
    b.belongs_to m, :user
    b.has_many m, :transactions, dependent: :destroy
  end

  profile = Tenant::Builder.model(:profile) do |b, m|
    b.attributes m, {
      bio: :text,
      avatar: :string,
      website: :string
    }
    b.belongs_to m, :user
  end

  post = Tenant::Builder.model(:post) do |b, m|
    b.attributes m, {
      title: :string,
      content: :text,
      published: :boolean,
      published_at: :datetime,
      slug: :string
    }
    b.belongs_to m, :user
    b.has_many m, :comments, dependent: :destroy
    b.has_and_belongs_to_many m, :categories
  end

  comment = Tenant::Builder.model(:comment) do |b, m|
    b.attributes m, {
      content: :text,
      approved: :boolean
    }
    b.belongs_to m, :post
    b.belongs_to m, :user
  end

  category = Tenant::Builder.model(:category) do |b, m|
    b.attributes m, {
      name: :string,
      slug: :string
    }
    b.has_and_belongs_to_many m, :posts
  end

  transaction = Tenant::Builder.model(:transaction) do |b, m|
    b.attributes m, {
      amount: :decimal,
      description: :string,
      transaction_date: :datetime
    }
    b.belongs_to m, :account
  end

  # validate and build all the models
  Tenant::Builder.generator(:ruby)
                .models([user, account, profile, post, comment, category, transaction])
                .execute
end
