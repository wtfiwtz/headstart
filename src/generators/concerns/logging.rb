require 'logger'

module Tenant
  module Logging
    def logger
      @logger ||= Logger.new(STDOUT).tap do |log|
        log.formatter = proc do |severity, datetime, progname, msg|
          date_format = datetime.strftime("%Y-%m-%d %H:%M:%S")
          "[#{date_format}] #{severity}: #{msg}\n"
        end
      end
    end
    
    def log_info(message)
      logger.info(message)
    end
    
    def log_warn(message)
      logger.warn(message)
    end
    
    def log_error(message)
      logger.error(message)
    end
    
    def log_debug(message)
      logger.debug(message)
    end
    
    def with_error_handling
      yield
    rescue StandardError => e
      log_error("Error: #{e.message}")
      log_error(e.backtrace.join("\n"))
      raise
    end
  end
end 