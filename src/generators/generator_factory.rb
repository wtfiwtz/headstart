module Tenant
  class GeneratorFactory
    def self.create(kind = :ruby)
      case kind
      when :ruby
        RubyGenerator.new
      when :node
        NodeGenerator.new
      when :python
        PythonGenerator.new
      else
        RubyGenerator.new
      end
    end
  end
end 