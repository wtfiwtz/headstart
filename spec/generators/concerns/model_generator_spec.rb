require 'spec_helper'
require 'test_helper'

RSpec.describe Tenant::ModelGenerator do
  # Create a test class that includes the ModelGenerator module
  let(:test_class) do
    Class.new do
      include Tenant::ModelGenerator
      include Tenant::Logging
      
      attr_accessor :models, :configuration, :rails_all_path
      
      def initialize(models, configuration = nil)
        @models = models
        @configuration = configuration
        @rails_all_path = Dir.mktmpdir('rails_generator_test')
        FileUtils.mkdir_p("#{@rails_all_path}/app/models")
      end
      
      def cleanup
        FileUtils.rm_rf(@rails_all_path) if @rails_all_path && File.directory?(@rails_all_path)
      end
    end
  end
  
  let(:models) { TestUtils.create_test_models }
  let(:configuration) { build(:application_configuration) }
  let(:generator) { test_class.new(models, configuration) }
  
  after do
    generator.cleanup
  end
  
  describe '#generate_models' do
    it 'generates model files for all models' do
      generator.generate_models
      
      models.each do |model|
        model_path = "#{generator.rails_all_path}/app/models/#{model.name.underscore}.rb"
        expect(File.exist?(model_path)).to be true
      end
    end
    
    it 'includes associations in the generated models' do
      generator.generate_models
      
      user_model_path = "#{generator.rails_all_path}/app/models/user.rb"
      user_model_content = File.read(user_model_path)
      
      expect(user_model_content).to include('has_many :posts')
      expect(user_model_content).to include('has_one :profile')
    end
    
    it 'includes validations in the generated models' do
      generator.generate_models
      
      user_model_path = "#{generator.rails_all_path}/app/models/user.rb"
      user_model_content = File.read(user_model_path)
      
      expect(user_model_content).to include('validates :email, presence: true')
      expect(user_model_content).to include('validates :name, presence: true')
    end
    
    it 'includes scopes in the generated models' do
      generator.generate_models
      
      user_model_path = "#{generator.rails_all_path}/app/models/user.rb"
      user_model_content = File.read(user_model_path)
      
      expect(user_model_content).to include('scope :recent')
      expect(user_model_content).to include('scope :admin')
    end
    
    context 'with search engine configuration' do
      let(:configuration) { build(:application_configuration, :with_elasticsearch) }
      
      it 'includes search engine integration in the generated models' do
        generator.generate_models
        
        user_model_path = "#{generator.rails_all_path}/app/models/user.rb"
        user_model_content = File.read(user_model_path)
        
        expect(user_model_content).to include('include Searchable')
        expect(user_model_content).to include('def self.searchable_fields')
      end
    end
    
    context 'with vector database configuration' do
      let(:configuration) do
        config = build(:application_configuration, :with_pgvector, :with_openai_embeddings)
        config
      end
      
      it 'includes vector database integration in the generated models' do
        # This test would be implemented once vector database support is added to the model generator
        pending "Vector database support not yet implemented in model generator"
        generator.generate_models
        
        user_model_path = "#{generator.rails_all_path}/app/models/user.rb"
        user_model_content = File.read(user_model_path)
        
        expect(user_model_content).to include('include VectorSearchable')
      end
    end
  end
  
  describe '#generate_associations' do
    it 'generates has_many associations correctly' do
      associations = generator.send(:generate_associations, models.first)
      
      expect(associations).to include('has_many :posts, dependent: :destroy')
    end
    
    it 'generates has_one associations correctly' do
      associations = generator.send(:generate_associations, models.first)
      
      expect(associations).to include('has_one :profile, dependent: :destroy')
    end
    
    it 'generates belongs_to associations correctly' do
      associations = generator.send(:generate_associations, models.last)
      
      expect(associations).to include('belongs_to :user')
    end
  end
  
  describe '#generate_validations' do
    it 'generates presence validations for common fields' do
      validations = generator.send(:generate_validations, models.first)
      
      expect(validations).to include('validates :email, presence: true')
      expect(validations).to include('validates :name, presence: true')
    end
    
    it 'generates format validations for email fields' do
      validations = generator.send(:generate_validations, models.first)
      
      expect(validations).to include('validates :email, format:')
    end
    
    it 'generates length validations for string fields' do
      validations = generator.send(:generate_validations, models.first)
      
      expect(validations).to include('validates :name, length:')
    end
  end
  
  describe '#generate_scopes' do
    it 'generates common scopes' do
      scopes = generator.send(:generate_scopes, models.first)
      
      expect(scopes).to include('scope :recent')
    end
    
    it 'generates scopes for boolean attributes' do
      scopes = generator.send(:generate_scopes, models.first)
      
      expect(scopes).to include('scope :admin')
      expect(scopes).to include('scope :not_admin')
    end
  end
end 