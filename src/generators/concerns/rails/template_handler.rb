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
      
      # Create default form template if it doesn't exist
      default_form_template = "#{form_templates_dir}/_form.html.erb"
      create_default_form_template(form_templates_dir) unless File.exist?(default_form_template)
    end
    
    def create_generated_controller_template
      template_dir = "#{@templates_path}"
      FileUtils.mkdir_p template_dir
      
      # Create the template file in the templates/rails directory
      template_content = <<~TEMPLATE
module Generated
  class <%= c_plural %>Controller < ApplicationController
    before_action :set_<%= singular %>, only: [:show, :edit, :update, :destroy]

    # GET /<%= plural %>
    def index
      @<%= plural %> = <%= c_singular %>.all
      
      respond_to do |format|
        format.html
        format.json { render json: @<%= plural %> }
      end
    end

    # GET /<%= plural %>/1
    def show
      respond_to do |format|
        format.html
        format.json { render json: @<%= singular %> }
      end
    end

    # GET /<%= plural %>/new
    def new
      @<%= singular %> = <%= c_singular %>.new
    end

    # GET /<%= plural %>/1/edit
    def edit
    end

    # POST /<%= plural %>
    def create
      @<%= singular %> = <%= c_singular %>.new(<%= singular %>_params)

      respond_to do |format|
        if @<%= singular %>.save
          format.html { redirect_to @<%= singular %>, notice: '<%= c_singular %> was successfully created.' }
          format.json { render json: @<%= singular %>, status: :created, location: @<%= singular %> }
        else
          format.html { render :new }
          format.json { render json: @<%= singular %>.errors, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /<%= plural %>/1
    def update
      respond_to do |format|
        if @<%= singular %>.update(<%= singular %>_params)
          format.html { redirect_to @<%= singular %>, notice: '<%= c_singular %> was successfully updated.' }
          format.json { render json: @<%= singular %>, status: :ok, location: @<%= singular %> }
        else
          format.html { render :edit }
          format.json { render json: @<%= singular %>.errors, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /<%= plural %>/1
    def destroy
      @<%= singular %>.destroy
      respond_to do |format|
        format.html { redirect_to <%= plural %>_url, notice: '<%= c_singular %> was successfully destroyed.' }
        format.json { head :no_content }
      end
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_<%= singular %>
        @<%= singular %> = <%= c_singular %>.find(params[:id])
      end

      # Only allow a list of trusted parameters through.
      def <%= singular %>_params
        params.require(:<%= singular %>).permit(<% attributes.each_with_index do |attr, i| %><%= i > 0 ? ', ' : '' %>:<%= attr %><% end %>)
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
class <%= c_plural %>Controller < Generated::<%= c_plural %>Controller
  # Add your custom controller logic here
  # This file won't be overwritten when you regenerate
end
TEMPLATE

      # Write the template to a file
      File.write("#{template_dir}/template_derived_controller.rb.erb", template_content)
      puts "Created template_derived_controller.rb.erb in #{template_dir}"
    end
    
    def create_default_form_template(dir)
      template_content = <<~TEMPLATE
<%%= form_with(model: @<%= singular %>, local: true) do |form| %>
  <%% if @<%= singular %>.errors.any? %>
    <div id="error_explanation">
      <h2><%%= pluralize(@<%= singular %>.errors.count, "error") %> prohibited this <%= singular %> from being saved:</h2>

      <ul>
        <%% @<%= singular %>.errors.full_messages.each do |message| %>
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
<%%= simple_form_for(@<%= singular %>) do |f| %>
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
<%%= semantic_form_for @<%= singular %> do |f| %>
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