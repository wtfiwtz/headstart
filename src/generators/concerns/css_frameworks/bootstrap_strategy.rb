module Tenant
  module CssFrameworks
    class BootstrapStrategy
      def setup(rails_path)
        FileUtils.chdir rails_path do
          # Add Bootstrap gems
          File.open("Gemfile", "a") do |f|
            f.puts "\n# Bootstrap"
            f.puts "gem 'bootstrap', '~> 5.2.0'"
            f.puts "gem 'jquery-rails'"
          end
          
          system "bundle install"
          
          # Create or update application.scss
          FileUtils.mkdir_p "app/assets/stylesheets" unless Dir.exist?("app/assets/stylesheets")
          
          # Rename application.css to application.scss if it exists
          if File.exist?("app/assets/stylesheets/application.css")
            FileUtils.mv("app/assets/stylesheets/application.css", "app/assets/stylesheets/application.scss")
          end
          
          # Add Bootstrap imports
          File.open("app/assets/stylesheets/application.scss", "a") do |f|
            f.puts "\n// Bootstrap"
            f.puts "@import 'bootstrap';"
          end
          
          # Add Bootstrap JavaScript
          File.open("app/javascript/packs/application.js", "a") do |f|
            f.puts "\n// Bootstrap"
            f.puts "import 'bootstrap'"
          end
          
          puts "Bootstrap installed successfully"
        end
      end
    end
  end
end 