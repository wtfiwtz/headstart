
module Tenant
  class BaseGenerator
    attr_accessor :model

    def models(models)
      self.model = models
      self
    end

    def execute
      validate
      generate
    end

    private

    def validate
      puts "Validate models: #{self.model}"
    end

    def generate
      setup_target
      puts "Generate models: #{self.model}"
      model.each do |m|
        puts "*** Model: #{m.name} ***"
        generate_model(m)
        generate_controller(m)
        generate_view(m)
      end
    end

    def setup_target
      raise "Not implemented"
    end

    def generate_model(m)
      raise "Not implemented"
    end

    def generate_controller(c)
      raise "Not implemented"
    end

    def generate_view(c)
      raise "Not implemented"
    end

    def generate_association(f, _model, association)
      raise "Not implemented"
    end
  end
end
