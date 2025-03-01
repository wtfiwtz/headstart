# require 'json'
require 'fileutils'
require 'erb'
require 'active_support/core_ext/string/inflections'
require_relative "./src/generators/base"
require_relative './src/generators/ruby'

ModelStruct = Struct.new(:name, :attributes, :associations)

module Tenant
  class Configuration
    attr_accessor :frontend, :gems, :features, :css_framework, :controller_inheritance, :form_builder, :monitoring
    
    def initialize
      @frontend = :mvc # Default to traditional MVC
      @gems = [] # List of gems to include
      @features = {} # Features to enable (e.g., authentication, file_upload)
      @css_framework = :bootstrap # Default to no CSS framework
      @controller_inheritance = true
      @form_builder = :default # Default Rails form builder (:simple_form, :formtastic)
      @monitoring = [] # List of monitoring tools to include (:new_relic, :datadog, :sentry)
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
        else RubyGenerator.new
        end
      end
    end
  end
end

# sample: form_for

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
