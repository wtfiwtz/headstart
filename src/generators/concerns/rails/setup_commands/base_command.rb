module Tenant
  module Rails
    class BaseCommand
      include Tenant::Logging
      
      attr_reader :rails_path, :configuration
      
      def initialize(rails_path, configuration)
        @rails_path = rails_path
        @configuration = configuration
      end
      
      def execute
        raise NotImplementedError, "Subclasses must implement execute method"
      end
    end
  end
end 