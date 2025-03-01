module Tenant
  module PackageManager
    def add_gems
      log "Adding gems to Gemfile"
      
      # Add gems based on CSS framework
      add_css_framework_gems if @css_framework
      
      # Add gems based on form builder
      add_form_builder_gems if @form_builder
      
      # Add gems based on template engine
      add_template_engine_gems if @template_engine && @template_engine != 'erb'
      
      # Add gems based on features
      add_feature_gems if @features && @features.any?
      
      # Add gems based on monitoring
      add_monitoring_gems if @monitoring && @monitoring.any?
      
      # Add custom gems
      add_custom_gems if @gems && @gems.any?
    end
    
    private
    
    def add_css_framework_gems
      case @css_framework.to_s.downcase
      when 'bootstrap'
        add_gem('bootstrap', '~> 5.2.0')
        add_gem('jquery-rails')
      when 'tailwind'
        add_gem('tailwindcss-rails')
      when 'bulma'
        add_gem('bulma-rails', '~> 0.9.4')
      when 'foundation'
        add_gem('foundation-rails', '~> 6.7.0')
      end
    end
    
    def add_form_builder_gems
      case @form_builder.to_s.downcase
      when 'simple_form'
        add_gem('simple_form')
      when 'formtastic'
        add_gem('formtastic')
      end
    end
    
    def add_template_engine_gems
      case @template_engine.to_s.downcase
      when 'slim'
        add_gem('slim-rails')
      when 'haml'
        add_gem('haml-rails')
      end
    end
    
    def add_feature_gems
      @features.each do |feature|
        case feature.to_s.downcase
        when 'authentication'
          add_gem('devise')
        when 'authorization'
          add_gem('pundit')
        when 'pagination'
          add_gem('kaminari')
        when 'search'
          add_gem('ransack')
        when 'api'
          add_gem('jbuilder')
          add_gem('rack-cors')
        when 'background_jobs'
          add_gem('sidekiq')
        when 'file_upload'
          add_gem('shrine')
        when 'pdf_generation'
          add_gem('wicked_pdf')
          add_gem('wkhtmltopdf-binary')
        when 'excel_export'
          add_gem('caxlsx')
          add_gem('caxlsx_rails')
        end
      end
    end
    
    def add_monitoring_gems
      @monitoring.each do |tool|
        case tool.to_s.downcase
        when 'sentry'
          add_gem('sentry-ruby')
          add_gem('sentry-rails')
        when 'newrelic'
          add_gem('newrelic_rpm')
        when 'skylight'
          add_gem('skylight')
        when 'scout'
          add_gem('scout_apm')
        when 'datadog'
          add_gem('ddtrace')
        end
      end
    end
    
    def add_custom_gems
      @gems.each do |gem_info|
        if gem_info.is_a?(Hash)
          add_gem(gem_info[:name], gem_info[:version], gem_info[:options])
        else
          add_gem(gem_info)
        end
      end
    end
    
    def add_gem(name, version = nil, options = {})
      log "Adding gem: #{name}"
      
      gemfile_path = "#{@rails_path}/Gemfile"
      gemfile_content = File.read(gemfile_path)
      
      # Check if gem is already in Gemfile
      return if gemfile_content.match(/^\s*gem\s+['"]#{name}['"]/)
      
      # Prepare gem line
      gem_line = "gem '#{name}'"
      gem_line += ", '#{version}'" if version
      
      if options && options.any?
        options_str = options.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
        gem_line += ", #{options_str}"
      end
      
      # Add gem to Gemfile
      updated_content = gemfile_content.gsub(/^group :development, :test do/, "gem '#{name}'#{version ? ", '#{version}'" : ''}\n\ngroup :development, :test do")
      
      File.write(gemfile_path, updated_content)
    end
  end
end 