module Tenant
  module CssFrameworks
    class TailwindStrategy
      def setup(rails_path)
        FileUtils.chdir rails_path do
          # Install Tailwind CSS
          system "yarn add tailwindcss postcss autoprefixer"
          
          # Create Tailwind config files
          system "npx tailwindcss init"
          
          # Create postcss.config.js
          File.open("postcss.config.js", "w") do |f|
            f.puts "module.exports = {"
            f.puts "  plugins: ["
            f.puts "    require('tailwindcss'),"
            f.puts "    require('autoprefixer'),"
            f.puts "  ]"
            f.puts "}"
          end
          
          # Update application.css
          FileUtils.mkdir_p "app/assets/stylesheets" unless Dir.exist?("app/assets/stylesheets")
          
          File.open("app/assets/stylesheets/application.css", "w") do |f|
            f.puts "/*"
            f.puts " * This is a manifest file that'll be compiled into application.css, which will include all the files"
            f.puts " * listed below."
            f.puts " *"
            f.puts "*= require_tree ."
            f.puts "*= require_self"
            f.puts " */"
            f.puts "@import 'tailwindcss/base';"
            f.puts "@import 'tailwindcss/components';"
            f.puts "@import 'tailwindcss/utilities';"
          end
          
          # Update tailwind.config.js to include your application's paths
          tailwind_config = File.read("tailwind.config.js")
          updated_config = tailwind_config.gsub(
            "content: [],", 
            "content: ['./app/views/**/*.html.erb', './app/helpers/**/*.rb', './app/javascript/**/*.js'],"
          )
          File.write("tailwind.config.js", updated_config)
          
          puts "Tailwind CSS installed successfully"
        end
      end
    end
  end
end 