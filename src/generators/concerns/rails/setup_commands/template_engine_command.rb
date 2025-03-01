module Tenant
  module Rails
    module SetupCommands
      class TemplateEngineCommand < BaseCommand
        def execute
          return unless @configuration.template_engine
          
          log_info "Setting up template engine: #{@configuration.template_engine}"
          
          case @configuration.template_engine.to_s.downcase
          when 'slim'
            setup_slim
          when 'haml'
            setup_haml
          else
            log_info "Using default ERB template engine"
          end
        end
        
        private
        
        def setup_slim
          # Add Slim gem if not already added
          unless @configuration.gems&.any? { |g| g.is_a?(Hash) ? g[:name] == 'slim-rails' : g == 'slim-rails' }
            add_gem('slim-rails')
          end
          
          # Create initializer for Slim
          create_slim_initializer
          
          log_info "Slim template engine setup completed"
        end
        
        def setup_haml
          # Add HAML gem if not already added
          unless @configuration.gems&.any? { |g| g.is_a?(Hash) ? g[:name] == 'haml-rails' : g == 'haml-rails' }
            add_gem('haml-rails')
          end
          
          # Create initializer for HAML
          create_haml_initializer
          
          log_info "HAML template engine setup completed"
        end
        
        def create_slim_initializer
          initializer_path = "#{@rails_path}/config/initializers/slim.rb"
          
          initializer_content = <<~RUBY
            # Slim template engine configuration
            Slim::Engine.set_options(
              format: :html5,
              pretty: Rails.env.development?,
              sort_attrs: false,
              shortcut: {
                '#' => { attr: 'id' },
                '.' => { attr: 'class' }
              }
            )
          RUBY
          
          File.write(initializer_path, initializer_content)
          log_info "Created Slim initializer at #{initializer_path}"
        end
        
        def create_haml_initializer
          initializer_path = "#{@rails_path}/config/initializers/haml.rb"
          
          initializer_content = <<~RUBY
            # HAML template engine configuration
            Haml::Template.options[:format] = :html5
            Haml::Template.options[:ugly] = !Rails.env.development?
            Haml::Template.options[:escape_html] = false
          RUBY
          
          File.write(initializer_path, initializer_content)
          log_info "Created HAML initializer at #{initializer_path}"
        end
        
        def add_gem(name, version = nil, options = {})
          log_info "Adding gem: #{name}"
          
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
          updated_content = gemfile_content.gsub(/^group :development, :test do/, "#{gem_line}\n\ngroup :development, :test do")
          
          File.write(gemfile_path, updated_content)
        end
      end
    end
  end
end 