require 'spec_helper'
require 'test_helper'

RSpec.describe Tenant::ControllerGenerator do
  # Create a test class that includes the ControllerGenerator module
  let(:test_class) do
    Class.new do
      include Tenant::ControllerGenerator
      include Tenant::Logging
      
      attr_accessor :models, :configuration, :rails_all_path, :templates_path
      
      def initialize(models, configuration = nil)
        @models = models
        @configuration = configuration
        @rails_all_path = Dir.mktmpdir('rails_generator_test')
        @templates_path = File.expand_path('../../../templates/rails', __dir__)
        
        # Create necessary directories
        FileUtils.mkdir_p("#{@rails_all_path}/app/controllers")
        FileUtils.mkdir_p("#{@rails_all_path}/app/controllers/generated")
      end
      
      def cleanup
        FileUtils.rm_rf(@rails_all_path) if @rails_all_path && File.directory?(@rails_all_path)
      end
    end
  end
  
  let(:models) { TestUtils.create_test_models }
  let(:configuration) { build(:application_configuration) }
  let(:generator) { test_class.new(models, configuration) }
  
  # Create mock template files for testing
  before do
    # Create a simple template file for testing
    FileUtils.mkdir_p(File.dirname(generator.templates_path))
    
    # Create template_controller.rb.erb
    File.open("#{generator.templates_path}/template_controller.rb.erb", 'w') do |f|
      f.puts "class <%= model.name.pluralize %>Controller < ApplicationController"
      f.puts "  # GET /<%= model.name.underscore.pluralize %>"
      f.puts "  def index"
      f.puts "    @<%= model.name.underscore.pluralize %> = <%= model.name %>.all"
      f.puts "  end"
      f.puts "end"
    end
    
    # Create template_derived_controller.rb.erb
    File.open("#{generator.templates_path}/template_derived_controller.rb.erb", 'w') do |f|
      f.puts "module Generated"
      f.puts "  class <%= model.name.pluralize %>Controller < ApplicationController"
      f.puts "    # GET /generated/<%= model.name.underscore.pluralize %>"
      f.puts "    def index"
      f.puts "      @<%= model.name.underscore.pluralize %> = <%= model.name %>.all"
      f.puts "    end"
      f.puts "  end"
      f.puts "end"
    end
  end
  
  after do
    generator.cleanup
    # Clean up template files
    FileUtils.rm_f("#{generator.templates_path}/template_controller.rb.erb")
    FileUtils.rm_f("#{generator.templates_path}/template_derived_controller.rb.erb")
  end
  
  describe '#generate_controllers' do
    it 'generates controller files for all models' do
      generator.generate_controllers
      
      models.each do |model|
        controller_path = "#{generator.rails_all_path}/app/controllers/#{model.name.underscore.pluralize}_controller.rb"
        expect(File.exist?(controller_path)).to be true
      end
    end
    
    it 'generates derived controller files when controller_inheritance is true' do
      generator.generate_controllers
      
      models.each do |model|
        derived_controller_path = "#{generator.rails_all_path}/app/controllers/generated/#{model.name.underscore.pluralize}_controller.rb"
        expect(File.exist?(derived_controller_path)).to be true
      end
    end
    
    it 'does not generate derived controller files when controller_inheritance is false' do
      generator.configuration.controller_inheritance = false
      generator.generate_controllers
      
      models.each do |model|
        derived_controller_path = "#{generator.rails_all_path}/app/controllers/generated/#{model.name.underscore.pluralize}_controller.rb"
        expect(File.exist?(derived_controller_path)).to be false
      end
    end
  end
  
  describe '#generate_controller_content' do
    it 'generates controller content using the template' do
      content = generator.send(:generate_controller_content, models.first)
      
      expect(content).to include('class UsersController < ApplicationController')
      expect(content).to include('def index')
      expect(content).to include('@users = User.all')
    end
  end
  
  describe '#generate_derived_controller_content' do
    it 'generates derived controller content using the template' do
      content = generator.send(:generate_derived_controller_content, models.first)
      
      expect(content).to include('module Generated')
      expect(content).to include('class UsersController < ApplicationController')
      expect(content).to include('def index')
      expect(content).to include('@users = User.all')
    end
  end
end 