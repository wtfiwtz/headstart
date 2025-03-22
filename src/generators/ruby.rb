require_relative './base'
require_relative './concerns/rails/template_handler'
require_relative './concerns/rails/route_generator'
require_relative './concerns/rails/association_handler'
require_relative './concerns/rails/configuration_handler'
require_relative './concerns/rails/model_generator'
require_relative './concerns/rails/controller_generator'
require_relative './concerns/rails/view_generator'
require_relative './concerns/rails/vector_database_handler'
require_relative './concerns/logging'
require_relative './plugin_system'
require 'yaml'
require 'ostruct'

# Setup commands
require_relative './concerns/rails/setup_commands/base_command'
# require_relative './concerns/rails/setup_commands/install_gems_command'
# require_relative './concerns/rails/setup_commands/controller_inheritance_command'
# require_relative './concerns/rails/setup_commands/css_framework_command'
# require_relative './concerns/rails/setup_commands/form_builder_command'
# require_relative './concerns/rails/setup_commands/features_command'
# require_relative './concerns/rails/setup_commands/monitoring_command'
# require_relative './concerns/rails/setup_commands/vector_database_command'
require_relative './concerns/rails/setup_commands/template_engine_command'

module Tenant
  class RubyGenerator < BaseGenerator
    include Tenant::TemplateHandler
    include Tenant::RouteGenerator
    include Tenant::Rails::AssociationHandler
    include Tenant::ConfigurationHandler
    include Tenant::ModelGenerator
    include Tenant::ControllerGenerator
    include Tenant::ViewGenerator
    include Tenant::VectorDatabaseHandler
    include Logging
    
    attr_accessor :configuration, :models

    def initialize
      @rails_all_path = "#{__dir__}/../../out/rails_app"
      @templates_path = "#{__dir__}/../../templates/rails"
      @configuration = nil
      @models = []
      
      # Ensure templates exist
      ensure_templates_exist
      
      log_info("Initialized RubyGenerator with rails_path: #{@rails_all_path}")
      log_info("Templates path: #{@templates_path}")
    end

    def apply_configuration(configuration)
      @configuration = configuration
      log_info("Configuration applied")
      self
    end

    def models(models_array)
      @models = models_array
      log_info("Models set: #{models_array.map(&:name).join(', ')}")
      self
    end

    def execute
      with_error_handling do
        log_info("Starting execution")
        
        setup_target
        
        # Run before generate hooks
        PluginSystem.run_hooks(:before_generate, @models)
        
        # Generate models, controllers, and views
        @models.each do |m|
          log_info("Generating model: #{m.name}")
          PluginSystem.run_hooks(:before_model_generate, m)
          generate_model(m)
          PluginSystem.run_hooks(:after_model_generate, m)
          
          log_info("Generating controller: #{m.name}")
          PluginSystem.run_hooks(:before_controller_generate, m)
          generate_controller(m.name, m.attributes, m.associations)
          PluginSystem.run_hooks(:after_controller_generate, m)
          
          log_info("Generating views: #{m.name}")
          PluginSystem.run_hooks(:before_view_generate, m)
          generate_view(m)
          PluginSystem.run_hooks(:after_view_generate, m)
        end
        
        # Generate routes after all models are processed
        log_info("Generating routes")
        PluginSystem.run_hooks(:before_routes_generate)
        generate_routes
        PluginSystem.run_hooks(:after_routes_generate)
        
        # Run after generate hooks
        PluginSystem.run_hooks(:after_generate, @models)
        
        log_info("Execution completed successfully")
      end
      
      self
    end

    def setup_target
      return if Dir.exist?("#{__dir__}/../../out/rails_app")

      log_info("Setting up target directory")
      FileUtils.mkdir_p "#{__dir__}/../../out"
      FileUtils.chdir "#{__dir__}/../../out"

      create_rails_app
      
      # Use command pattern for setup steps
      commands = [
        Tenant::Rails::SetupCommands::ControllerInheritanceCommand.new,
        Tenant::Rails::SetupCommands::InstallGemsCommand.new,
        Tenant::Rails::SetupCommands::CssFrameworkCommand.new,
        Tenant::Rails::SetupCommands::FormBuilderCommand.new,
        Tenant::Rails::SetupCommands::FeaturesCommand.new,
        Tenant::Rails::SetupCommands::MonitoringCommand.new
      ]
      
      commands.each do |command|
        log_info("Executing setup command: #{command.class.name}")
        command.execute(@rails_all_path, @configuration)
      end
      
      log_info("Target setup completed")
    end

    def create_rails_app
      log_info("Creating Rails application")
      case @configuration&.frontend
      when :react
        log_info("Using React frontend")
        system "rails new rails_app --webpack=react"
      when :vue
        log_info("Using Vue.js frontend")
        system "rails new rails_app --webpack=vue"
      else
        log_info("Using standard Rails MVC")
      system "rails new rails_app"
      end
    end

    def install_gems
      return unless @configuration&.gems&.any?
      
      gemfile_path = "#{@rails_all_path}/Gemfile"
      gemfile_content = File.read(gemfile_path)
      
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
    end

    def setup_css_framework
      return unless @configuration&.css_framework
      
      log_info("Setting up CSS framework: #{@configuration.css_framework}")
      command = Tenant::Rails::SetupCommands::CssFrameworkCommand.new
      command.execute(@rails_all_path, @configuration)
    end
     
    def setup_features
      return unless @configuration&.features&.any?
      
      log_info("Setting up features")
      
      # Execute setup commands
      Tenant::Rails::SetupCommands::FeaturesCommand.new(@configuration, @rails_all_path).execute
      
      # Setup CSS framework if specified
      Tenant::Rails::SetupCommands::CssFrameworkCommand.new(@configuration, @rails_all_path).execute if @configuration.css_framework
      
      # Setup form builder if specified
      Tenant::Rails::SetupCommands::FormBuilderCommand.new(@configuration, @rails_all_path).execute if @configuration.form_builder
      
      # Setup template engine if specified
      Tenant::Rails::SetupCommands::TemplateEngineCommand.new(@configuration, @rails_all_path).execute if @configuration.template_engine
      
      # Setup monitoring if specified
      Tenant::Rails::SetupCommands::MonitoringCommand.new(@configuration, @rails_all_path).execute if @configuration.monitoring&.any?
      
      # Setup vector database if specified
      Tenant::Rails::SetupCommands::VectorDatabaseCommand.new(@configuration, @rails_all_path).execute if @configuration.vector_db
    end
    
    def setup_form_builder
      return unless @configuration&.form_builder
      
      log_info("Setting up form builder: #{@configuration.form_builder}")
      command = Tenant::Rails::SetupCommands::FormBuilderCommand.new
      command.execute(@rails_all_path, @configuration)
    end
    
    def update_form_templates
      # Create form templates directory if it doesn't exist
      form_templates_dir = "#{@templates_path}/views"
      FileUtils.mkdir_p form_templates_dir
      
      # Create form template based on the chosen form builder
      case @configuration.form_builder
      when :simple_form
        create_simple_form_template(form_templates_dir)
      when :formtastic
        create_formtastic_template(form_templates_dir)
      else
        create_default_form_template(form_templates_dir)
      end
    end

    def configure_rodauth(options = {})
      # Implementation similar to previous example
      # ...
    end

    def generate_model(m)
      base_path = "#{@rails_all_path}/app/models"
      FileUtils.mkdir_p base_path
      File.open("#{base_path}/#{m.name}.rb", 'w') do |f|
        f.write("class #{m.name.capitalize} < ActiveRecord::Base\n")
        
        # Add validations based on attributes
        generate_validations(f, m)
        
        # Add associations
        m.associations.each do |a|
          puts "Association: #{a}"
          generate_association(f, m, a)
        end
        
        # Add scopes
        generate_scopes(f, m)
        
        # Add callback methods if needed
        generate_callbacks(f, m)
        
        f.write("end\n")
      end
    end

    def generate_validations(f, model)
      # Add basic validations based on attribute types
      model.attributes.each do |attr_name, attr_type|
        case attr_type
        when :string, :text
          if attr_name.to_s == 'email'
            f.write("  validates :#{attr_name}, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }\n")
          elsif attr_name.to_s == 'name' || attr_name.to_s == 'title'
            f.write("  validates :#{attr_name}, presence: true\n")
          end
        when :integer, :decimal, :float
          if attr_name.to_s.end_with?('_count') || attr_name.to_s.end_with?('_amount')
            f.write("  validates :#{attr_name}, numericality: { greater_than_or_equal_to: 0 }\n")
          end
        end
      end
      
      # Add presence validations for belongs_to associations
      model.associations.each do |assoc|
        if assoc[:kind] == :belongs_to && !assoc[:attrs][:optional]
          f.write("  validates :#{assoc[:name]}_id, presence: true\n")
        end
      end
      
      f.write("\n") if model.attributes.any? || model.associations.any?
    end
    
    def generate_scopes(f, model)
      # Add common scopes based on attributes
      has_timestamps = model.attributes.keys.include?(:created_at) || 
                       model.attributes.keys.include?(:updated_at)
      
      if has_timestamps
        f.write("  scope :recent, -> { order(created_at: :desc) }\n")
      end
      
      if model.attributes.keys.include?(:active) || model.attributes.keys.include?(:status)
        status_field = model.attributes.keys.include?(:active) ? :active : :status
        if status_field == :active
          f.write("  scope :active, -> { where(active: true) }\n")
          f.write("  scope :inactive, -> { where(active: false) }\n")
        else
          f.write("  scope :active, -> { where(status: 'active') }\n")
          f.write("  scope :inactive, -> { where.not(status: 'active') }\n")
        end
      end
      
      f.write("\n") if has_timestamps || model.attributes.keys.include?(:active) || model.attributes.keys.include?(:status)
    end
    
    def generate_callbacks(f, model)
      # Add callback methods if needed based on model attributes
      needs_callbacks = false
      
      if model.attributes.keys.include?(:slug) && model.attributes.keys.include?(:name)
        f.write("  before_validation :generate_slug, if: -> { name_changed? || slug.blank? }\n\n")
        f.write("  private\n\n")
        f.write("  def generate_slug\n")
        f.write("    self.slug = name.to_s.parameterize\n")
        f.write("  end\n")
        needs_callbacks = true
      end
      
      f.write("\n") if needs_callbacks
    end

    def generate_controller(model_name, attributes, associations = [])
      controller_path = File.join(@rails_all_path, 'app', 'controllers', "#{model_name.underscore.pluralize}_controller.rb")
      template_path = File.join(@templates_path, 'template_controller.rb.erb')
      
      # Create a model object that matches the template's expectations
      model = OpenStruct.new(
        name: model_name,
        attributes: attributes.map { |name, type| OpenStruct.new(name: name, type: type) },
        associations: associations.map { |assoc| OpenStruct.new(assoc) }
      )
      
      locals = {
        model: model,
        configuration: @configuration
      }
      
      write_template(template_path, controller_path, locals)
      
      # Generate base controller if needed
      generate_base_controller(model_name, attributes, associations) if @configuration&.controller_inheritance
    end

    def generate_base_controller(model_name, attributes, associations = [])
      controller_path = File.join(@rails_all_path, 'app', 'controllers', 'generated', "#{model_name.underscore.pluralize}_controller.rb")
      template_path = File.join(@templates_path, 'template_generated_controller.rb.erb')
      
      # Create a model object that matches the template's expectations
      model = OpenStruct.new(
        name: model_name,
        attributes: attributes.map { |name, type| OpenStruct.new(name: name, type: type) },
        associations: associations.map { |assoc| OpenStruct.new(assoc) }
      )
      
      locals = {
        model: model,
        configuration: @configuration
      }
      
      write_template(template_path, controller_path, locals)
    end

    def generate_derived_controller(name, hsh)
      base_path = "#{@rails_all_path}/app/controllers"
      target = "#{base_path}/#{name.pluralize}_controller.rb"
      
      # Only create the derived controller if it doesn't exist
      unless File.exist?(target)
        src = "#{@templates_path}/template_derived_controller.rb.erb"
        write_template(:controller, base_path, src, target, "#{name.pluralize}_controller.rb", hsh)
      else
        puts "Skipped existing #{name.pluralize}_controller.rb"
      end
    end

    def create_generated_controller_template
      template_dir = "#{@templates_path}"
      FileUtils.mkdir_p template_dir
      
      # Create the template file in the templates/rails directory
      template_content = <<~TEMPLATE
module Generated
  class <%= model.name.pluralize %>Controller < ApplicationController
    before_action :set_<%= model.name.underscore %>, only: [:show, :edit, :update, :destroy]

    # GET /<%= model.name.pluralize %>
    def index
      @<%= model.name.pluralize %> = <%= model.name.underscore.pluralize %>.all
      
      respond_to do |format|
        format.html
        format.json { render json: @<%= model.name.pluralize %> }
      end
    end

    # GET /<%= model.name.pluralize %>/1
    def show
      respond_to do |format|
        format.html
        format.json { render json: @<%= model.name.underscore %> }
      end
    end

    # GET /<%= model.name.pluralize %>/new
    def new
      @<%= model.name.underscore %> = <%= c_singular %>.new
    end

    # GET /<%= model.name.pluralize %>/1/edit
    def edit
    end

    # POST /<%= model.name.pluralize %>
    def create
      @<%= model.name.underscore %> = <%= c_singular %>.new(<%= model.name.underscore %>_params)

      respond_to do |format|
        if @<%= model.name.underscore %>.save
          format.html { redirect_to @<%= model.name.underscore %>, notice: '<%= c_singular %> was successfully created.' }
          format.json { render json: @<%= model.name.underscore %>, status: :created, location: @<%= model.name.underscore %> }
        else
          format.html { render :new }
          format.json { render json: @<%= model.name.underscore %>.errors, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /<%= model.name.pluralize %>/1
    def update
      respond_to do |format|
        if @<%= model.name.underscore %>.update(<%= model.name.underscore %>_params)
          format.html { redirect_to @<%= model.name.underscore %>, notice: '<%= c_singular %> was successfully updated.' }
          format.json { render json: @<%= model.name.underscore %>, status: :ok, location: @<%= model.name.underscore %> }
        else
          format.html { render :edit }
          format.json { render json: @<%= model.name.underscore %>.errors, status: :unprocessable_entity }
        end
      end

    # DELETE /<%= model.name.pluralize %>/1
    def destroy
      @<%= model.name.underscore %>.destroy
      respond_to do |format|
        format.html { redirect_to <%= model.name.pluralize %>_url, notice: '<%= c_singular %> was successfully destroyed.' }
        format.json { head :no_content }
      end
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_<%= model.name.underscore %>
        @<%= model.name.underscore %> = <%= c_singular %>.find(params[:id])
      end

      # Only allow a list of trusted parameters through.
      def <%= model.name.underscore %>_params
        params.require(:<%= model.name.underscore %>).permit(<% attributes.each_with_index do |attr, i| %><%= i > 0 ? ', ' : '' %>:<%= attr %><% end %>)
      end
  end
end
TEMPLATE

      # Write the template to a file
      File.write("#{template_dir}/template_generated_controller.rb.erb", template_content)
      puts "Created template_generated_controller.rb.erb in #{template_dir}"
    end

    def create_derived_controller_template
      template_dir = "#{@templates_path}"
      
      # Create the template file in the templates/rails directory
      template_content = <<~TEMPLATE
class <%= model.name.pluralize %>Controller < Generated::<%= model.name.pluralize %>Controller
  # Add your custom controller logic here
  # This file won't be overwritten when you regenerate
end
TEMPLATE

      # Write the template to a file
      File.write("#{template_dir}/template_derived_controller.rb.erb", template_content)
      puts "Created template_derived_controller.rb.erb in #{template_dir}"
    end

    def ensure_templates_exist
      # Ensure templates directory exists
      FileUtils.mkdir_p @templates_path
      
      # Create the generated controller template if it doesn't exist
      generated_controller_template = "#{@templates_path}/template_generated_controller.rb.erb"
      create_generated_controller_template unless File.exist?(generated_controller_template)
      
      # Create the derived controller template if it doesn't exist
      derived_controller_template = "#{@templates_path}/template_derived_controller.rb.erb"
      create_derived_controller_template unless File.exist?(derived_controller_template)
      
      # Create the controller template if it doesn't exist
      controller_template = "#{@templates_path}/template_controller.rb.erb"
      create_controller_template unless File.exist?(controller_template)
      
      # Create form templates directory
      form_templates_dir = "#{@templates_path}/views"
      FileUtils.mkdir_p form_templates_dir
      
      # Create default form template if it doesn't exist
      default_form_template = "#{form_templates_dir}/_form.html.erb"
      create_default_form_template(form_templates_dir) unless File.exist?(default_form_template)
      
      # Add more template creation calls here as needed
    end

    def generate_view(m)
      name = m.name.to_s.gsub(/[^A-Za-z0-9]/, '').downcase
      
      # Create locals hash with all necessary variables
      locals = {
        model: m,
        attributes: m.attributes.map { |name, type| OpenStruct.new(name: name, type: type) },
        singular: name,
        plural: name.pluralize,
        c_singular: name.capitalize,
        c_plural: name.pluralize.capitalize,
        configuration: @configuration
      }
      
      # Create views directory
      views_dir = File.join(@rails_all_path, 'app', 'views', name.pluralize)
      FileUtils.mkdir_p(views_dir)
      
      # Define view templates to generate
      view_templates = {
        '_form.html.erb' => '_form.html.erb',
        'edit.html.erb' => 'edit.html.erb',
        'index.html.erb' => 'index.html.erb',
        'new.html.erb' => 'new.html.erb',
        'show.html.erb' => 'show.html.erb',
        'index.json.jbuilder' => 'index.json.jbuilder',
        'show.json.jbuilder' => 'show.json.jbuilder'
      }
      
      # Generate each view
      view_templates.each do |template_name, output_name|
        template_path = File.join(@templates_path, 'views', template_name)
        output_path = File.join(views_dir, output_name)
        
        write_template(template_path, output_path, locals)
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

    def write_template(template_path, output_path, locals = {})
      template = File.read(template_path)
      
      # Create a new binding for the template
      template_binding = binding
      
      # Add locals to the binding
      locals.each do |key, value|
        template_binding.local_variable_set(key, value)
      end
      
      # Render the template with the locals
      result = ERB.new(template, trim_mode: '-').result(template_binding)
      
      # Ensure the output directory exists
      FileUtils.mkdir_p(File.dirname(output_path))
      
      # Write the result to the output file
      File.write(output_path, result)
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
      options = build_association_options(association)
      options_str = options.empty? ? "" : ", #{options.join(', ')}"
      
      case association[:kind]
      when :has_one
        f.write("  has_one :#{association[:name]}#{options_str}\n")
      when :has_many
        f.write("  has_many :#{association[:name]}#{options_str}\n")
      when :belongs_to
        f.write("  belongs_to :#{association[:name]}#{options_str}\n")
      when :has_and_belongs_to_many
        f.write("  has_and_belongs_to_many :#{association[:name]}#{options_str}\n")
      end
    end

    def build_association_options(association)
      return [] unless association[:attrs]
      
      options = []
      attrs = association[:attrs]
      
      # Handle dependent option
      if attrs[:dependent]
        options << "dependent: :#{attrs[:dependent]}"
      elsif association[:kind] == :has_many || association[:kind] == :has_one
        # Default to nullify for safety
        options << "dependent: :nullify"
      end
      
      # Handle through option for has_many :through
      options << "through: :#{attrs[:through]}" if attrs[:through]
      
      # Handle source option for has_many :through
      options << "source: :#{attrs[:source]}" if attrs[:source]
      
      # Handle class_name option
      options << "class_name: '#{attrs[:class_name]}'" if attrs[:class_name]
      
      # Handle foreign_key option
      options << "foreign_key: :#{attrs[:foreign_key]}" if attrs[:foreign_key]
      
      # Handle optional for belongs_to (Rails 5+)
      options << "optional: #{attrs[:optional]}" if association[:kind] == :belongs_to && attrs.key?(:optional)
      
      # Handle polymorphic
      options << "polymorphic: true" if attrs[:polymorphic]
      
      # Handle as for polymorphic belongs_to
      options << "as: :#{attrs[:as]}" if attrs[:as]
      
      # Handle counter_cache
      if attrs[:counter_cache]
        counter_value = attrs[:counter_cache] == true ? "true" : ":#{attrs[:counter_cache]}"
        options << "counter_cache: #{counter_value}"
      end
      
      # Handle validate option
      options << "validate: #{attrs[:validate]}" if attrs.key?(:validate)
      
      # Handle autosave option
      options << "autosave: #{attrs[:autosave]}" if attrs.key?(:autosave)
      
      options
    end

    def create_default_form_template(dir)
      template_content = <<~TEMPLATE
<%%= form_with(model: @<%= model.name.underscore %>, local: true) do |form| %>
  <%% if @<%= model.name.underscore %>.errors.any? %>
    <div id="error_explanation">
      <h2><%%= pluralize(@<%= model.name.underscore %>.errors.count, "error") %> prohibited this <%= model.name.underscore %> from being saved:</h2>

      <ul>
        <%% @<%= model.name.underscore %>.errors.full_messages.each do |message| %>
          <li><%%= message %></li>
        <%% end %>
      </ul>
    </div>
  <%% end %>

<% attributes.each do |attribute| %>
  <div class="field">
    <%%= form.label :<%= attribute %> %>
    <%%= form.text_field :<%= attribute %>, class: 'form-control' %>
  </div>
<% end %>

  <div class="actions">
    <%%= form.submit class: 'btn btn-primary' %>
  </div>
<%% end %>
TEMPLATE

      File.write("#{dir}/_form.html.erb", template_content)
      puts "Created default form template in #{dir}/_form.html.erb"
    end
    
    def create_simple_form_template(dir)
      template_content = <<~TEMPLATE
<%%= simple_form_for(@<%= model.name.underscore %>) do |f| %>
  <%%= f.error_notification %>
  <%%= f.error_notification message: f.object.errors[:base].to_sentence if f.object.errors[:base].present? %>

  <div class="form-inputs">
<% attributes.each do |attribute| %>
    <%%= f.input :<%= attribute %> %>
<% end %>
  </div>

  <div class="form-actions">
    <%%= f.button :submit, class: 'btn btn-primary' %>
  </div>
<%% end %>
TEMPLATE

      File.write("#{dir}/_form.html.erb", template_content)
      puts "Created Simple Form template in #{dir}/_form.html.erb"
    end
    
    def create_formtastic_template(dir)
      template_content = <<~TEMPLATE
<%%= semantic_form_for @<%= model.name.underscore %> do |f| %>
  <%%= f.inputs do %>
<% attributes.each do |attribute| %>
    <%%= f.input :<%= attribute %> %>
<% end %>
  <%% end %>
  
  <%%= f.actions do %>
    <%%= f.action :submit, as: :button, button_html: { class: 'btn btn-primary' } %>
    <%%= f.action :cancel, as: :link, button_html: { class: 'btn btn-secondary' } %>
  <%% end %>
<%% end %>
TEMPLATE

      File.write("#{dir}/_form.html.erb", template_content)
      puts "Created Formtastic template in #{dir}/_form.html.erb"
    end

    def setup_monitoring
      return unless @configuration&.monitoring&.any?
      
      log_info("Setting up monitoring: #{@configuration.monitoring.join(', ')}")
      command = Tenant::Rails::SetupCommands::MonitoringCommand.new
      command.execute(@rails_all_path, @configuration)
    end

    def generate_routes
      routes_path = "#{@rails_all_path}/config/routes.rb"
      
      # Read the current routes file
      current_routes = File.read(routes_path)
      
      # Find the Rails.application.routes.draw block
      routes_block_match = current_routes.match(/Rails\.application\.routes\.draw do\s*\n(.*?)\nend/m)
      
      if routes_block_match
        # Extract the current routes content
        routes_content = routes_block_match[1]
        
        # Generate new routes for each model
        new_routes = generate_routes_for_models
        
        # Check if the routes already exist
        new_routes.each do |route|
          unless routes_content.include?(route.strip)
            routes_content += "  #{route}\n"
          end
        end
        
        # Replace the routes block with the updated content
        updated_routes = current_routes.sub(
          /Rails\.application\.routes\.draw do\s*\n.*?\nend/m,
          "Rails.application.routes.draw do\n#{routes_content}\nend"
        )
        
        # Write the updated routes back to the file
        File.write(routes_path, updated_routes)
        
        puts "Updated routes in config/routes.rb"
      else
        puts "Could not find the routes block in config/routes.rb"
      end
    end
    
    def generate_routes_for_models
      routes = []
      
      # Process each model to generate appropriate routes
      @models.each do |model|
        routes.concat(generate_routes_for_model(model))
      end
      
      # Add root route if we have a suitable model
      root_route = determine_root_route
      routes << root_route if root_route
      
      routes
    end
    
    def generate_routes_for_model(model)
      model_routes = []
      model_name = model.name.to_s
      plural_name = model_name.pluralize
      
      # Check for nested resources
      nested_resources = find_nested_resources(model)
      
      if nested_resources.any?
        # Generate nested routes
        nested_resources.each do |parent_model|
          model_routes.concat(generate_nested_routes(parent_model, model))
        end
      else
        # Generate standard RESTful routes
        model_routes << "resources :#{plural_name}"
      end
      
      # Add member and collection routes if needed
      member_routes = generate_member_routes(model)
      collection_routes = generate_collection_routes(model)
      
      if member_routes.any? || collection_routes.any?
        # Remove the simple route if we're going to replace it with a block
        model_routes.delete("resources :#{plural_name}")
        model_routes.concat(generate_resource_block(plural_name, member_routes, collection_routes))
      end
      
      model_routes
    end
    
    def generate_nested_routes(parent_model, child_model)
      parent_name = parent_model.name.to_s
      parent_plural = parent_name.pluralize
      child_plural = child_model.name.to_s.pluralize
      
      [
        "resources :#{parent_plural} do",
        "  resources :#{child_plural}",
        "end"
      ]
    end
    
    def generate_resource_block(resource_name, member_routes, collection_routes)
      route_block = ["resources :#{resource_name} do"]
      
      if member_routes.any?
        route_block << "  member do"
        member_routes.each do |member_route|
          route_block << "    #{member_route}"
        end
        route_block << "  end"
      end
      
      if collection_routes.any?
        route_block << "  collection do"
        collection_routes.each do |collection_route|
          route_block << "    #{collection_route}"
        end
        route_block << "  end"
      end
      
      route_block << "end"
      route_block
    end
    
    def find_nested_resources(model)
      # Find models that this model belongs to
      nested_resources = []
      
      model.associations.each do |assoc|
        if assoc[:kind] == :belongs_to
          # Find the parent model
          parent_model = @models.find { |m| m.name.to_s == assoc[:name].to_s.singularize }
          nested_resources << parent_model if parent_model
        end
      end
      
      nested_resources
    end
    
    def generate_member_routes(model)
      member_routes = []
      
      # Add common member routes based on model attributes
      if model.attributes.keys.include?(:active) || model.attributes.keys.include?(:status)
        member_routes << "get :activate"
        member_routes << "get :deactivate"
      end
      
      if model.attributes.keys.include?(:position)
        member_routes << "put :move_up"
        member_routes << "put :move_down"
      end
      
      # Add archive/unarchive if there's an archived_at attribute
      if model.attributes.keys.include?(:archived_at)
        member_routes << "put :archive"
        member_routes << "put :unarchive"
      end
      
      member_routes
    end
    
    def generate_collection_routes(model)
      collection_routes = []
      
      # Add common collection routes
      if model.attributes.keys.include?(:active) || model.attributes.keys.include?(:status)
        collection_routes << "get :active"
        collection_routes << "get :inactive"
      end
      
      # Add export routes if it's a data-heavy model
      if model.attributes.keys.count >= 5
        collection_routes << "get :export"
      end
      
      # Add import route for specific model types
      importable_modules = %w[product user customer account]
      if importable_modules.include?(model.name.to_s.downcase)
        collection_routes << "post :import"
      end
      
      # Add search if the model has searchable attributes
      searchable_attrs = [:name, :title, :description, :email, :username].select do |attr|
        model.attributes.keys.include?(attr)
      end
      
      if searchable_attrs.any?
        collection_routes << "get :search"
      end
      
      collection_routes
    end
    
    def determine_root_route
      # Try to find a suitable model for the root route
      dashboard_model = @models.find { |m| m.name.to_s == 'dashboard' }
      return "root to: 'dashboards#index'" if dashboard_model
      
      home_model = @models.find { |m| m.name.to_s == 'home' }
      return "root to: 'homes#index'" if home_model
      
      # Look for common models that might serve as a landing page
      %w[post article page product].each do |model_name|
        model = @models.find { |m| m.name.to_s == model_name }
        return "root to: '#{model_name.pluralize}#index'" if model
      end
      
      # Default to the first model if nothing else is suitable
      return "root to: '#{@models.first.name.to_s.pluralize}#index'" if @models.any?
      
      nil
    end

    def load_models_from_yaml(yaml_path)
      log_info("Loading models from YAML file: #{yaml_path}")
      
      begin
        yaml_content = YAML.load_file(yaml_path)
        models_array = []
        
        yaml_content['models'].each do |model_name, model_data|
          model = OpenStruct.new(
            name: model_name,
            attributes: {},
            associations: []
          )
          
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
        
        log_info("Loaded #{models_array.size} models from YAML")
        @models = models_array
        self
      rescue StandardError => e
        log_error("Error loading models from YAML: #{e.message}")
        raise
      end
    end
  end
end

