require_relative './base'

module Tenant
  class RubyGenerator < BaseGenerator
    def initialize
      @rails_all_path = "#{__dir__}/../../out/rails_app"
    end

    def generate_model(m)
      base_path = "#{@rails_all_path}/app/models"
      FileUtils.mkdir_p base_path
      File.open("#{base_path}/#{m.name}.rb", 'w') do |f|
        f.write("class #{m.name.capitalize} < ActiveRecord::Base\n")
        m.associations.each do |a|
          puts "Association: #{a}"
          generate_association(f, m, a)
        end
        f.write("end\n")
      end
    end

    def generate_controller(m)
      base_path = "#{@rails_all_path}/app/controllers"
      FileUtils.mkdir_p base_path
      erb = ERB.new(File.read("#{__dir__}/../../templates/rails/template_controller.rb.erb"))
      erb.filename = "#{__dir__}/../../templates/rails/template_controller.rb.erb"
      name = m.name.to_s.gsub(/[^A-Za-z0-9]/, '').downcase
      keys = m.attributes.keys.map(&:to_s)
      hsh = { :singular => name,
              :c_singular => name.capitalize,
              :plural => name.pluralize,
              :c_plural => name.pluralize.capitalize,
              :attributes => keys }
      out = erb.result_with_hash(hsh)
      file = File.open("#{base_path}/#{name.pluralize}_controller.rb", 'w')
      File.write(file, out)
      puts "Generated #{base_path}/#{name.pluralize}_controller.rb"
    end

    def generate_controller_basic(m)
      base_path = "#{@rails_all_path}/app/controllers"
      FileUtils.mkdir_p base_path
      File.open("#{base_path}/#{m.name}_controller.rb", 'w') do |f|
        f.write("class #{m.name.capitalize}Controller < ApplicationController\n")
        f.write("  def index\n")
        f.write("  end\n")
        f.write("\n")
        f.write("  def show\n")
        f.write("  end\n")
        f.write("\n")
        f.write("  def edit\n")
        f.write("  end\n")
        f.write("\n")
        f.write("  def create\n")
        f.write("  end\n")
        f.write("\n")
        f.write("  def update\n")
        f.write("  end\n")
        f.write("\n")
        f.write("  def delete\n")
        f.write("  end\n")
        f.write("end\n")
      end
    end

    def generate_association(f, _model, association)
      case association[:kind]
      when :has_one
        f.write("  has_one :#{association[:name]}\n")
      when :has_many
        f.write("  has_many :#{association[:name]}\n")
      when :belongs_to
        f.write("  belongs_to :#{association[:name]}\n")
      end
    end
  end
end

