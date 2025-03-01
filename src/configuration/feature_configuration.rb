module Tenant
  module Configuration
    class FeatureConfiguration
      attr_accessor :provider, :options
      
      def initialize(provider, options = {})
        @provider = provider
        @options = options
      end
      
      def to_h
        {
          provider: @provider,
          options: @options
        }
      end
    end
    
    class AuthenticationConfiguration < FeatureConfiguration
      attr_accessor :generate_user, :passkeys, :passkey_options
      
      def initialize(provider = :rodauth, options = {})
        super(provider, options)
        @generate_user = options.delete(:generate_user) || false
        @passkeys = options.delete(:passkeys) || false
        @passkey_options = options.delete(:passkey_options) || {}
      end
      
      def to_h
        super.merge(
          generate_user: @generate_user,
          passkeys: @passkeys,
          passkey_options: @passkey_options
        )
      end
    end
    
    class FileUploadConfiguration < FeatureConfiguration
      def initialize(provider = :active_storage, options = {})
        super(provider, options)
      end
    end
    
    class BackgroundJobsConfiguration < FeatureConfiguration
      def initialize(provider = :sidekiq, options = {})
        super(provider, options)
      end
    end
  end
end 