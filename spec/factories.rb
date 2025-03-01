FactoryBot.define do
  factory :application_configuration, class: 'Tenant::Configuration::ApplicationConfiguration' do
    frontend { :mvc }
    css_framework { :bootstrap }
    controller_inheritance { true }
    form_builder { :default }
    database { :sqlite }
    
    trait :with_postgresql do
      database { :postgresql }
      database_options { { username: 'postgres', password: 'password' } }
    end
    
    trait :with_mysql do
      database { :mysql }
      database_options { { username: 'root', password: 'password' } }
    end
    
    trait :with_elasticsearch do
      search_engine { :elasticsearch }
      search_engine_options { { host: 'http://localhost:9200' } }
    end
    
    trait :with_meilisearch do
      search_engine { :meilisearch }
      search_engine_options { { host: 'http://localhost:7700' } }
    end
    
    trait :with_pgvector do
      vector_db { :pgvector }
      vector_db_options { { dimensions: 1536 } }
    end
    
    trait :with_openai_embeddings do
      embedding_provider { :openai }
      embedding_provider_options { { model: 'text-embedding-ada-002' } }
    end
    
    trait :with_authentication do
      after(:build) do |config|
        config.enable_authentication(:devise, { generate_user: true })
      end
    end
    
    trait :with_file_upload do
      after(:build) do |config|
        config.enable_file_upload(:active_storage)
      end
    end
    
    trait :with_background_jobs do
      after(:build) do |config|
        config.enable_background_jobs(:sidekiq)
      end
    end
  end
  
  factory :gem_configuration, class: 'Tenant::Configuration::GemConfiguration' do
    name { 'rails' }
    version { '~> 7.0' }
    options { {} }
    
    initialize_with { new(name, version, options) }
  end
  
  factory :model_attribute, class: 'OpenStruct' do
    sequence(:name) { |n| "attribute_#{n}" }
    type { 'string' }
    
    trait :string do
      type { 'string' }
    end
    
    trait :text do
      type { 'text' }
    end
    
    trait :integer do
      type { 'integer' }
    end
    
    trait :boolean do
      type { 'boolean' }
    end
    
    trait :datetime do
      type { 'datetime' }
    end
    
    initialize_with { new(name: name, type: type) }
  end
  
  factory :model_association, class: 'OpenStruct' do
    kind { 'belongs_to' }
    sequence(:name) { |n| "association_#{n}" }
    attrs { {} }
    
    trait :belongs_to do
      kind { 'belongs_to' }
    end
    
    trait :has_one do
      kind { 'has_one' }
    end
    
    trait :has_many do
      kind { 'has_many' }
    end
    
    trait :has_and_belongs_to_many do
      kind { 'has_and_belongs_to_many' }
    end
    
    initialize_with { new(kind: kind, name: name, attrs: attrs) }
  end
  
  factory :model, class: 'OpenStruct' do
    sequence(:name) { |n| "Model#{n}" }
    attributes { [] }
    associations { [] }
    
    trait :with_attributes do
      attributes do
        [
          build(:model_attribute, name: 'name', type: 'string'),
          build(:model_attribute, name: 'description', type: 'text'),
          build(:model_attribute, name: 'active', type: 'boolean')
        ]
      end
    end
    
    trait :with_associations do
      associations do
        [
          build(:model_association, :belongs_to, name: 'user'),
          build(:model_association, :has_many, name: 'comments', attrs: { dependent: :destroy })
        ]
      end
    end
    
    initialize_with { new(name: name, attributes: attributes, associations: associations) }
  end
end 