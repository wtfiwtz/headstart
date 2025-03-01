module Tenant
  module SetupCommands
    class BaseCommand
      def execute(rails_path, configuration)
        raise NotImplementedError, "Subclasses must implement execute"
      end
    end
  end
end 