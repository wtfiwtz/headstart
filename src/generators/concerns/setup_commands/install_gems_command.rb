module Tenant
  module SetupCommands
    class InstallGemsCommand < BaseCommand
      def execute(rails_path, configuration)
        return unless configuration&.gems&.any?
        
        gemfile_path = "#{rails_path}/Gemfile"
        gemfile_content = File.read(gemfile_path)
        
        configuration.gems.each do |gem_info|
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
        FileUtils.chdir rails_path do
          system "bundle install"
        end
      end
    end
  end
end 