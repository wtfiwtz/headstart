require_relative '../css_frameworks/bootstrap_strategy'
require_relative '../css_frameworks/tailwind_strategy'

module Tenant
  module SetupCommands
    class CssFrameworkCommand < BaseCommand
      def execute(rails_path, configuration)
        return unless configuration&.css_framework && configuration.css_framework != :none
        
        strategy = case configuration.css_framework
                   when :bootstrap
                     CssFrameworks::BootstrapStrategy.new
                   when :tailwind
                     CssFrameworks::TailwindStrategy.new
                   else
                     return
                   end
        
        strategy.setup(rails_path)
      end
    end
  end
end 