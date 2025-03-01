module Tenant
  module Configuration
    class GemConfiguration
      attr_accessor :name, :version, :options
      
      def initialize(name, version = nil, options = {})
        @name = name
        @version = version
        @options = options
      end
      
      def to_h
        {
          name: @name,
          version: @version,
          options: @options
        }
      end
    end
  end
end 