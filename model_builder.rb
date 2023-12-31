# require 'json'
require 'fileutils'
require 'erb'
require 'active_support/core_ext/string/inflections'
require_relative "./src/generators/base"
require_relative './src/generators/ruby'

module Tenant
  class Builder
    class << self
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

user = Tenant::Builder.model(:user) do |b, m|
  b.attributes m, {
    name: :string,
    email: :string,
    password: :string
  }
  b.has_many m, :accounts
end

account = Tenant::Builder.model(:account) do |b, m|
  b.attributes m, {
    name: :string,
    number: :string
  }
  b.belongs_to m, :user
end

# validate and build all the models
Tenant::Builder.generator(:ruby) \
               .models([user, account]) \
               .execute
