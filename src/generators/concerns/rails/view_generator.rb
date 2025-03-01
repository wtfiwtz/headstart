module Tenant
  module ViewGenerator
    def generate_views
      log "Generating views for #{@models.size} models"
      @models.each do |model|
        generate_view(model)
      end
    end

    def generate_view(model)
      log "Generating views for model: #{model[:name]}"
      
      # Create views directory if it doesn't exist
      views_dir = "#{@rails_path}/app/views/#{model[:name].underscore.pluralize}"
      FileUtils.mkdir_p(views_dir)
      
      # Generate views based on the configured template engine
      generate_index_view(model, views_dir)
      generate_show_view(model, views_dir)
      generate_new_view(model, views_dir)
      generate_edit_view(model, views_dir)
      generate_form_partial(model, views_dir)
    end

    private

    def generate_index_view(model, views_dir)
      file_extension = template_file_extension
      file_path = "#{views_dir}/index.html.#{file_extension}"
      
      content = case @template_engine.to_s.downcase
      when 'slim'
        generate_slim_index_view(model)
      when 'haml'
        generate_haml_index_view(model)
      else # default to ERB
        generate_erb_index_view(model)
      end
      
      File.write(file_path, content)
    end

    def generate_show_view(model, views_dir)
      file_extension = template_file_extension
      file_path = "#{views_dir}/show.html.#{file_extension}"
      
      content = case @template_engine.to_s.downcase
      when 'slim'
        generate_slim_show_view(model)
      when 'haml'
        generate_haml_show_view(model)
      else # default to ERB
        generate_erb_show_view(model)
      end
      
      File.write(file_path, content)
    end

    def generate_new_view(model, views_dir)
      file_extension = template_file_extension
      file_path = "#{views_dir}/new.html.#{file_extension}"
      
      content = case @template_engine.to_s.downcase
      when 'slim'
        generate_slim_new_view(model)
      when 'haml'
        generate_haml_new_view(model)
      else # default to ERB
        generate_erb_new_view(model)
      end
      
      File.write(file_path, content)
    end

    def generate_edit_view(model, views_dir)
      file_extension = template_file_extension
      file_path = "#{views_dir}/edit.html.#{file_extension}"
      
      content = case @template_engine.to_s.downcase
      when 'slim'
        generate_slim_edit_view(model)
      when 'haml'
        generate_haml_edit_view(model)
      else # default to ERB
        generate_erb_edit_view(model)
      end
      
      File.write(file_path, content)
    end

    def generate_form_partial(model, views_dir)
      file_extension = template_file_extension
      file_path = "#{views_dir}/_form.html.#{file_extension}"
      
      content = case @template_engine.to_s.downcase
      when 'slim'
        generate_slim_form_partial(model)
      when 'haml'
        generate_haml_form_partial(model)
      else # default to ERB
        generate_erb_form_partial(model)
      end
      
      File.write(file_path, content)
    end

    # Helper method to get the file extension based on template engine
    def template_file_extension
      case @template_engine.to_s.downcase
      when 'slim'
        'slim'
      when 'haml'
        'haml'
      else
        'erb'
      end
    end

    # ERB template generators
    def generate_erb_index_view(model)
      model_name = model[:name]
      model_plural = model_name.underscore.pluralize
      model_singular = model_name.underscore
      
      <<~ERB
        <div class="container mx-auto px-4 py-8">
          <div class="flex justify-between items-center mb-6">
            <h1 class="text-2xl font-bold">#{model_name.pluralize}</h1>
            <%= link_to 'New #{model_name}', new_#{model_singular}_path, class: 'btn btn-primary' %>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full bg-white">
              <thead class="bg-gray-100">
                <tr>
                  <% # Table headers %>
                  #{model[:attributes].keys.map { |attr| "<th class=\"py-2 px-4 border-b\">#{attr.to_s.humanize}</th>" }.join("\n                  ")}
                  <th class="py-2 px-4 border-b">Actions</th>
                </tr>
              </thead>
              <tbody>
                <% @#{model_plural}.each do |#{model_singular}| %>
                  <tr>
                    <% # Table cells %>
                    #{model[:attributes].keys.map { |attr| "<td class=\"py-2 px-4 border-b\"><%= #{model_singular}.#{attr} %></td>" }.join("\n                    ")}
                    <td class="py-2 px-4 border-b">
                      <%= link_to 'Show', #{model_singular}, class: 'btn btn-sm btn-info' %>
                      <%= link_to 'Edit', edit_#{model_singular}_path(#{model_singular}), class: 'btn btn-sm btn-warning' %>
                      <%= link_to 'Delete', #{model_singular}, method: :delete, data: { confirm: 'Are you sure?' }, class: 'btn btn-sm btn-danger' %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      ERB
    end

    def generate_erb_show_view(model)
      model_name = model[:name]
      model_singular = model_name.underscore
      
      <<~ERB
        <div class="container mx-auto px-4 py-8">
          <div class="bg-white shadow rounded p-6">
            <h1 class="text-2xl font-bold mb-6">#{model_name} Details</h1>
            
            <% # Display attributes %>
            #{model[:attributes].keys.map { |attr| "<div class=\"mb-4\">\n              <strong class=\"block text-gray-700\">#{attr.to_s.humanize}:</strong>\n              <p class=\"text-gray-900\"><%= @#{model_singular}.#{attr} %></p>\n            </div>" }.join("\n            ")}
            
            <div class="mt-6 flex space-x-4">
              <%= link_to 'Edit', edit_#{model_singular}_path(@#{model_singular}), class: 'btn btn-warning' %>
              <%= link_to 'Back', #{model_plural}_path, class: 'btn btn-secondary' %>
            </div>
          </div>
        </div>
      ERB
    end

    def generate_erb_new_view(model)
      model_name = model[:name]
      model_singular = model_name.underscore
      
      <<~ERB
        <div class="container mx-auto px-4 py-8">
          <div class="bg-white shadow rounded p-6">
            <h1 class="text-2xl font-bold mb-6">New #{model_name}</h1>
            
            <%= render 'form', #{model_singular}: @#{model_singular} %>
            
            <div class="mt-6">
              <%= link_to 'Back', #{model_plural}_path, class: 'btn btn-secondary' %>
            </div>
          </div>
        </div>
      ERB
    end

    def generate_erb_edit_view(model)
      model_name = model[:name]
      model_singular = model_name.underscore
      
      <<~ERB
        <div class="container mx-auto px-4 py-8">
          <div class="bg-white shadow rounded p-6">
            <h1 class="text-2xl font-bold mb-6">Editing #{model_name}</h1>
            
            <%= render 'form', #{model_singular}: @#{model_singular} %>
            
            <div class="mt-6 flex space-x-4">
              <%= link_to 'Show', @#{model_singular}, class: 'btn btn-info' %>
              <%= link_to 'Back', #{model_plural}_path, class: 'btn btn-secondary' %>
            </div>
          </div>
        </div>
      ERB
    end

    def generate_erb_form_partial(model)
      model_name = model[:name]
      model_singular = model_name.underscore
      
      form_content = if @form_builder == 'simple_form'
        generate_simple_form_erb(model)
      else
        generate_standard_form_erb(model)
      end
      
      <<~ERB
        <%= form_with(model: #{model_singular}, local: true) do |form| %>
          <% if #{model_singular}.errors.any? %>
            <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
              <h2 class="font-bold mb-2"><%= pluralize(#{model_singular}.errors.count, "error") %> prohibited this #{model_singular} from being saved:</h2>
              <ul class="list-disc pl-5">
                <% #{model_singular}.errors.full_messages.each do |message| %>
                  <li><%= message %></li>
                <% end %>
              </ul>
            </div>
          <% end %>

          #{form_content}

          <div class="mt-6">
            <%= form.submit class: 'btn btn-primary' %>
          </div>
        <% end %>
      ERB
    end

    def generate_standard_form_erb(model)
      model[:attributes].keys.map do |attr|
        <<~ERB
          <div class="mb-4">
            <%= form.label :#{attr}, class: 'block text-gray-700 font-bold mb-2' %>
            <%= form.text_field :#{attr}, class: 'shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline' %>
          </div>
        ERB
      end.join("\n          ")
    end

    def generate_simple_form_erb(model)
      model[:attributes].keys.map do |attr|
        <<~ERB
          <div class="mb-4">
            <%= form.input :#{attr} %>
          </div>
        ERB
      end.join("\n          ")
    end

    # SLIM template generators
    def generate_slim_index_view(model)
      model_name = model[:name]
      model_plural = model_name.underscore.pluralize
      model_singular = model_name.underscore
      
      <<~SLIM
        .container.mx-auto.px-4.py-8
          .flex.justify-between.items-center.mb-6
            h1.text-2xl.font-bold #{model_name.pluralize}
            = link_to 'New #{model_name}', new_#{model_singular}_path, class: 'btn btn-primary'

          .overflow-x-auto
            table.min-w-full.bg-white
              thead.bg-gray-100
                tr
                  #{model[:attributes].keys.map { |attr| "th.py-2.px-4.border-b #{attr.to_s.humanize}" }.join("\n                  ")}
                  th.py-2.px-4.border-b Actions
              tbody
                - @#{model_plural}.each do |#{model_singular}|
                  tr
                    #{model[:attributes].keys.map { |attr| "td.py-2.px-4.border-b = #{model_singular}.#{attr}" }.join("\n                    ")}
                    td.py-2.px-4.border-b
                      = link_to 'Show', #{model_singular}, class: 'btn btn-sm btn-info'
                      = link_to 'Edit', edit_#{model_singular}_path(#{model_singular}), class: 'btn btn-sm btn-warning'
                      = link_to 'Delete', #{model_singular}, method: :delete, data: { confirm: 'Are you sure?' }, class: 'btn btn-sm btn-danger'
      SLIM
    end

    def generate_slim_show_view(model)
      model_name = model[:name]
      model_singular = model_name.underscore
      model_plural = model_name.underscore.pluralize
      
      <<~SLIM
        .container.mx-auto.px-4.py-8
          .bg-white.shadow.rounded.p-6
            h1.text-2xl.font-bold.mb-6 #{model_name} Details
            
            #{model[:attributes].keys.map { |attr| ".mb-4\n              strong.block.text-gray-700 #{attr.to_s.humanize}:\n              p.text-gray-900 = @#{model_singular}.#{attr}" }.join("\n            ")}
            
            .mt-6.flex.space-x-4
              = link_to 'Edit', edit_#{model_singular}_path(@#{model_singular}), class: 'btn btn-warning'
              = link_to 'Back', #{model_plural}_path, class: 'btn btn-secondary'
      SLIM
    end

    def generate_slim_new_view(model)
      model_name = model[:name]
      model_singular = model_name.underscore
      model_plural = model_name.underscore.pluralize
      
      <<~SLIM
        .container.mx-auto.px-4.py-8
          .bg-white.shadow.rounded.p-6
            h1.text-2xl.font-bold.mb-6 New #{model_name}
            
            = render 'form', #{model_singular}: @#{model_singular}
            
            .mt-6
              = link_to 'Back', #{model_plural}_path, class: 'btn btn-secondary'
      SLIM
    end

    def generate_slim_edit_view(model)
      model_name = model[:name]
      model_singular = model_name.underscore
      model_plural = model_name.underscore.pluralize
      
      <<~SLIM
        .container.mx-auto.px-4.py-8
          .bg-white.shadow.rounded.p-6
            h1.text-2xl.font-bold.mb-6 Editing #{model_name}
            
            = render 'form', #{model_singular}: @#{model_singular}
            
            .mt-6.flex.space-x-4
              = link_to 'Show', @#{model_singular}, class: 'btn btn-info'
              = link_to 'Back', #{model_plural}_path, class: 'btn btn-secondary'
      SLIM
    end

    def generate_slim_form_partial(model)
      model_name = model[:name]
      model_singular = model_name.underscore
      
      form_content = if @form_builder == 'simple_form'
        generate_simple_form_slim(model)
      else
        generate_standard_form_slim(model)
      end
      
      <<~SLIM
        = form_with(model: #{model_singular}, local: true) do |form|
          - if #{model_singular}.errors.any?
            .bg-red-100.border.border-red-400.text-red-700.px-4.py-3.rounded.mb-4
              h2.font-bold.mb-2 = pluralize(#{model_singular}.errors.count, "error") + " prohibited this #{model_singular} from being saved:"
              ul.list-disc.pl-5
                - #{model_singular}.errors.full_messages.each do |message|
                  li = message

          #{form_content}

          .mt-6
            = form.submit class: 'btn btn-primary'
      SLIM
    end

    def generate_standard_form_slim(model)
      model[:attributes].keys.map do |attr|
        <<~SLIM
          .mb-4
            = form.label :#{attr}, class: 'block text-gray-700 font-bold mb-2'
            = form.text_field :#{attr}, class: 'shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline'
        SLIM
      end.join("\n          ")
    end

    def generate_simple_form_slim(model)
      model[:attributes].keys.map do |attr|
        <<~SLIM
          .mb-4
            = form.input :#{attr}
        SLIM
      end.join("\n          ")
    end

    # HAML template generators
    def generate_haml_index_view(model)
      model_name = model[:name]
      model_plural = model_name.underscore.pluralize
      model_singular = model_name.underscore
      
      <<~HAML
        .container.mx-auto.px-4.py-8
          .flex.justify-between.items-center.mb-6
            %h1.text-2xl.font-bold #{model_name.pluralize}
            = link_to 'New #{model_name}', new_#{model_singular}_path, class: 'btn btn-primary'

          .overflow-x-auto
            %table.min-w-full.bg-white
              %thead.bg-gray-100
                %tr
                  #{model[:attributes].keys.map { |attr| "%th.py-2.px-4.border-b #{attr.to_s.humanize}" }.join("\n                  ")}
                  %th.py-2.px-4.border-b Actions
              %tbody
                - @#{model_plural}.each do |#{model_singular}|
                  %tr
                    #{model[:attributes].keys.map { |attr| "%td.py-2.px-4.border-b= #{model_singular}.#{attr}" }.join("\n                    ")}
                    %td.py-2.px-4.border-b
                      = link_to 'Show', #{model_singular}, class: 'btn btn-sm btn-info'
                      = link_to 'Edit', edit_#{model_singular}_path(#{model_singular}), class: 'btn btn-sm btn-warning'
                      = link_to 'Delete', #{model_singular}, method: :delete, data: { confirm: 'Are you sure?' }, class: 'btn btn-sm btn-danger'
      HAML
    end

    def generate_haml_show_view(model)
      model_name = model[:name]
      model_singular = model_name.underscore
      model_plural = model_name.underscore.pluralize
      
      <<~HAML
        .container.mx-auto.px-4.py-8
          .bg-white.shadow.rounded.p-6
            %h1.text-2xl.font-bold.mb-6 #{model_name} Details
            
            #{model[:attributes].keys.map { |attr| ".mb-4\n              %strong.block.text-gray-700 #{attr.to_s.humanize}:\n              %p.text-gray-900= @#{model_singular}.#{attr}" }.join("\n            ")}
            
            .mt-6.flex.space-x-4
              = link_to 'Edit', edit_#{model_singular}_path(@#{model_singular}), class: 'btn btn-warning'
              = link_to 'Back', #{model_plural}_path, class: 'btn btn-secondary'
      HAML
    end

    def generate_haml_new_view(model)
      model_name = model[:name]
      model_singular = model_name.underscore
      model_plural = model_name.underscore.pluralize
      
      <<~HAML
        .container.mx-auto.px-4.py-8
          .bg-white.shadow.rounded.p-6
            %h1.text-2xl.font-bold.mb-6 New #{model_name}
            
            = render 'form', #{model_singular}: @#{model_singular}
            
            .mt-6
              = link_to 'Back', #{model_plural}_path, class: 'btn btn-secondary'
      HAML
    end

    def generate_haml_edit_view(model)
      model_name = model[:name]
      model_singular = model_name.underscore
      model_plural = model_name.underscore.pluralize
      
      <<~HAML
        .container.mx-auto.px-4.py-8
          .bg-white.shadow.rounded.p-6
            %h1.text-2xl.font-bold.mb-6 Editing #{model_name}
            
            = render 'form', #{model_singular}: @#{model_singular}
            
            .mt-6.flex.space-x-4
              = link_to 'Show', @#{model_singular}, class: 'btn btn-info'
              = link_to 'Back', #{model_plural}_path, class: 'btn btn-secondary'
      HAML
    end

    def generate_haml_form_partial(model)
      model_name = model[:name]
      model_singular = model_name.underscore
      
      form_content = if @form_builder == 'simple_form'
        generate_simple_form_haml(model)
      else
        generate_standard_form_haml(model)
      end
      
      <<~HAML
        = form_with(model: #{model_singular}, local: true) do |form|
          - if #{model_singular}.errors.any?
            .bg-red-100.border.border-red-400.text-red-700.px-4.py-3.rounded.mb-4
              %h2.font-bold.mb-2= pluralize(#{model_singular}.errors.count, "error") + " prohibited this #{model_singular} from being saved:"
              %ul.list-disc.pl-5
                - #{model_singular}.errors.full_messages.each do |message|
                  %li= message

          #{form_content}

          .mt-6
            = form.submit class: 'btn btn-primary'
      HAML
    end

    def generate_standard_form_haml(model)
      model[:attributes].keys.map do |attr|
        <<~HAML
          .mb-4
            = form.label :#{attr}, class: 'block text-gray-700 font-bold mb-2'
            = form.text_field :#{attr}, class: 'shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline'
        HAML
      end.join("\n          ")
    end

    def generate_simple_form_haml(model)
      model[:attributes].keys.map do |attr|
        <<~HAML
          .mb-4
            = form.input :#{attr}
        HAML
      end.join("\n          ")
    end
  end
end 