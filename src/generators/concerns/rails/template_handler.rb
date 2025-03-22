module Tenant
  module TemplateHandler
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
    
    def ensure_templates_exist
      # Ensure templates directory exists
      FileUtils.mkdir_p @templates_path
      
      # Create the generated controller template if it doesn't exist
      generated_controller_template = "#{@templates_path}/template_generated_controller.rb.erb"
      create_generated_controller_template unless File.exist?(generated_controller_template)
      
      # Create the derived controller template if it doesn't exist
      derived_controller_template = "#{@templates_path}/template_derived_controller.rb.erb"
      create_derived_controller_template unless File.exist?(derived_controller_template)
      
      # Create form templates directory
      form_templates_dir = "#{@templates_path}/views"
      FileUtils.mkdir_p form_templates_dir
      
      # Create form templates based on the configured template engine
      create_form_templates(form_templates_dir)
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
      @<%= model.name.pluralize %> = <%= c_singular %>.all
      
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
    
    def create_form_templates(dir)
      # Create form templates based on the configured template engine
      case @template_engine.to_s.downcase
      when 'slim'
        create_slim_form_templates(dir)
      when 'haml'
        create_haml_form_templates(dir)
      else
        create_erb_form_templates(dir)
      end
    end
    
    def create_erb_form_templates(dir)
      # Create default form template
      create_default_form_template(dir) unless File.exist?("#{dir}/_form.html.erb")
      
      # Create form template based on the chosen form builder
      case @form_builder.to_s.downcase
      when 'simple_form'
        create_simple_form_template(dir)
      when 'formtastic'
        create_formtastic_template(dir)
      end
    end
    
    def create_slim_form_templates(dir)
      # Create default Slim form template
      create_default_slim_form_template(dir) unless File.exist?("#{dir}/_form.html.slim")
      
      # Create form template based on the chosen form builder
      case @form_builder.to_s.downcase
      when 'simple_form'
        create_simple_form_slim_template(dir)
      when 'formtastic'
        create_formtastic_slim_template(dir)
      end
    end
    
    def create_haml_form_templates(dir)
      # Create default HAML form template
      create_default_haml_form_template(dir) unless File.exist?("#{dir}/_form.html.haml")
      
      # Create form template based on the chosen form builder
      case @form_builder.to_s.downcase
      when 'simple_form'
        create_simple_form_haml_template(dir)
      when 'formtastic'
        create_formtastic_haml_template(dir)
      end
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
      puts "Created default ERB form template in #{dir}/_form.html.erb"
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
      puts "Created Simple Form ERB template in #{dir}/_form.html.erb"
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
      puts "Created Formtastic ERB template in #{dir}/_form.html.erb"
    end
    
    def create_default_slim_form_template(dir)
      template_content = <<~TEMPLATE
= form_with(model: @<%= model.name.underscore %>, local: true) do |form|
  - if @<%= model.name.underscore %>.errors.any?
    #error_explanation
      h2 = pluralize(@<%= model.name.underscore %>.errors.count, "error") + " prohibited this <%= model.name.underscore %> from being saved:"
      ul
        - @<%= model.name.underscore %>.errors.full_messages.each do |message|
          li = message

<% attributes.each do |attribute| %>
  .field
    = form.label :<%= attribute %>
    = form.text_field :<%= attribute %>, class: 'form-control'
<% end %>

  .actions
    = form.submit class: 'btn btn-primary'
TEMPLATE

      File.write("#{dir}/_form.html.slim", template_content)
      puts "Created default Slim form template in #{dir}/_form.html.slim"
    end
    
    def create_simple_form_slim_template(dir)
      template_content = <<~TEMPLATE
= simple_form_for(@<%= model.name.underscore %>) do |f|
  = f.error_notification
  = f.error_notification message: f.object.errors[:base].to_sentence if f.object.errors[:base].present?

  .form-inputs
<% attributes.each do |attribute| %>
    = f.input :<%= attribute %>
<% end %>

  .form-actions
    = f.button :submit, class: 'btn btn-primary'
TEMPLATE

      File.write("#{dir}/_form.html.slim", template_content)
      puts "Created Simple Form Slim template in #{dir}/_form.html.slim"
    end
    
    def create_formtastic_slim_template(dir)
      template_content = <<~TEMPLATE
= semantic_form_for @<%= model.name.underscore %> do |f|
  = f.inputs do
<% attributes.each do |attribute| %>
    = f.input :<%= attribute %>
<% end %>
  
  = f.actions do
    = f.action :submit, as: :button, button_html: { class: 'btn btn-primary' }
    = f.action :cancel, as: :link, button_html: { class: 'btn btn-secondary' }
TEMPLATE

      File.write("#{dir}/_form.html.slim", template_content)
      puts "Created Formtastic Slim template in #{dir}/_form.html.slim"
    end
    
    def create_default_haml_form_template(dir)
      template_content = <<~TEMPLATE
= form_with(model: @<%= model.name.underscore %>, local: true) do |form|
  - if @<%= model.name.underscore %>.errors.any?
    #error_explanation
      %h2= pluralize(@<%= model.name.underscore %>.errors.count, "error") + " prohibited this <%= model.name.underscore %> from being saved:"
      %ul
        - @<%= model.name.underscore %>.errors.full_messages.each do |message|
          %li= message

<% attributes.each do |attribute| %>
  .field
    = form.label :<%= attribute %>
    = form.text_field :<%= attribute %>, class: 'form-control'
<% end %>

  .actions
    = form.submit class: 'btn btn-primary'
TEMPLATE

      File.write("#{dir}/_form.html.haml", template_content)
      puts "Created default HAML form template in #{dir}/_form.html.haml"
    end
    
    def create_simple_form_haml_template(dir)
      template_content = <<~TEMPLATE
= simple_form_for(@<%= model.name.underscore %>) do |f|
  = f.error_notification
  = f.error_notification message: f.object.errors[:base].to_sentence if f.object.errors[:base].present?

  .form-inputs
<% attributes.each do |attribute| %>
    = f.input :<%= attribute %>
<% end %>

  .form-actions
    = f.button :submit, class: 'btn btn-primary'
TEMPLATE

      File.write("#{dir}/_form.html.haml", template_content)
      puts "Created Simple Form HAML template in #{dir}/_form.html.haml"
    end
    
    def create_formtastic_haml_template(dir)
      template_content = <<~TEMPLATE
= semantic_form_for @<%= model.name.underscore %> do |f|
  = f.inputs do
<% attributes.each do |attribute| %>
    = f.input :<%= attribute %>
<% end %>
  
  = f.actions do
    = f.action :submit, as: :button, button_html: { class: 'btn btn-primary' }
    = f.action :cancel, as: :link, button_html: { class: 'btn btn-secondary' }
TEMPLATE

      File.write("#{dir}/_form.html.haml", template_content)
      puts "Created Formtastic HAML template in #{dir}/_form.html.haml"
    end
    
    def update_form_templates
      # Create form templates directory if it doesn't exist
      form_templates_dir = "#{@templates_path}/views"
      FileUtils.mkdir_p form_templates_dir
      
      # Create form templates based on the configured template engine
      create_form_templates(form_templates_dir)
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
      
      # Determine file extension based on template engine
      extension = case @template_engine.to_s.downcase
                  when 'slim'
                    'slim'
                  when 'haml'
                    'haml'
                  else
                    'erb'
                  end
      
      srcs = %W[_form.html.#{extension} _template.html.#{extension} _template.json.jbuilder edit.html.#{extension}
                index.html.#{extension} index.json.jbuilder new.html.#{extension} show.html.#{extension} show.json.jbuilder]
      targets = ["_form.html.#{extension}", "_#{name.pluralize}.html.#{extension}", "_#{name.pluralize}.json.jbuilder",
                 "edit.html.#{extension}", "index.html.#{extension}", "index.json.jbuilder", "new.html.#{extension}", "show.html.#{extension}",
                 "show.json.jbuilder"]
      src = "#{@templates_path}/views/#{srcs[view_file]}"
      target = "#{base_path}/#{name.pluralize}/#{targets[view_file]}"
      [base_path, src, target, targets[view_file]]
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
  end
end 