require_relative './base'

module Tenant
  class RubyGenerator < BaseGenerator
    def initialize
      @rails_all_path = "#{__dir__}/../../out/rails_app"
      @templates_path = "#{__dir__}/../../templates/rails"
    end

    def setup_target
      return if Dir.exist?("#{__dir__}/../../out/rails_app")
      FileUtils.mkdir_p "#{__dir__}/../../out"
      FileUtils.chdir "#{__dir__}/../../out"
      system "rails new rails_app"
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
      name, hsh = build_name_and_hash(m)
      base_path, src, target, target_name = controller_paths(:controller, name)
      write_template(:controller, base_path, src, target, target_name, hsh)
    end

    def generate_view(m)
      name, hsh = build_name_and_hash(m)
      (0..8).each do |view_file|
        base_path, src, target, target_name = view_paths(:view, name, view_file)
        write_template(:view, base_path, src, target, target_name, hsh)
      end
    end

    def build_name_and_hash(m)
      name = m.name.to_s.gsub(/[^A-Za-z0-9]/, '').downcase
      hsh = build_hash(name, m)
      [name, hsh]
    end

    def build_hash(name, m)
      keys = m.attributes.keys.map(&:to_s)
      { :singular => name,
        :c_singular => name.capitalize,
        :plural => name.pluralize,
        :c_plural => name.pluralize.capitalize,
        :attributes => keys }
    end

    def controller_paths(kind, name)
      base_path = "#{@rails_all_path}/app/#{kind}s"
      src = "#{@templates_path}/template_#{kind}.rb.erb"
      target = "#{base_path}/#{name.pluralize}_#{kind}.rb"
      [base_path, src, target, "#{name.pluralize}_#{kind}.rb"]
    end

    def view_paths(kind, name, view_file)
      raise "View file #{view_file} out of range" unless (0..8).include?(view_file)
      base_path = "#{@rails_all_path}/app/#{kind}s"
      srcs = %w[_form.html.erb _template.html.erb _template.json.jbuilder edit.html.erb
                index.html.erb index.json.jbuilder new.html.erb show.html.erb show.json.jbuilder]
      targets = ['_form.html.erb', "_#{name.pluralize}.html.erb", "_#{name.pluralize}.json.jbuilder",
                 'edit.html.erb', 'index.html.erb', 'index.json.jbuilder', 'new.html.erb', 'show.html.erb',
                 'show.json.jbuilder']
      src = "#{@templates_path}/views/#{srcs[view_file]}"
      target = "#{base_path}/#{name.pluralize}/#{targets[view_file]}"
      [base_path, src, target, targets[view_file]]
    end

    def write_template(kind, base_path, src, target, target_name, hsh)
      FileUtils.mkdir_p base_path
      FileUtils.mkdir_p "#{base_path}/#{hsh[:plural]}" if kind == :view
      erb = ERB.new(File.read(src))
      erb.filename = src
      out = erb.result_with_hash(hsh)
      file = File.open(target, 'w')
      File.write(file, out)
      puts "Generated #{target_name}"
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

