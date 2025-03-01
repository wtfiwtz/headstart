module Tenant
  module Rails
    module AssociationHandler
      def generate_association(f, _model, association)
        options = build_association_options(association)
        options_str = options.empty? ? "" : ", #{options.join(', ')}"
        
        case association[:kind]
        when :has_one
          f.write("  has_one :#{association[:name]}#{options_str}\n")
        when :has_many
          f.write("  has_many :#{association[:name]}#{options_str}\n")
        when :belongs_to
          f.write("  belongs_to :#{association[:name]}#{options_str}\n")
        when :has_and_belongs_to_many
          f.write("  has_and_belongs_to_many :#{association[:name]}#{options_str}\n")
        end
      end
      
      def build_association_options(association)
        return [] unless association[:attrs]
        
        options = []
        attrs = association[:attrs]
        
        # Handle dependent option
        if attrs[:dependent]
          options << "dependent: :#{attrs[:dependent]}"
        elsif association[:kind] == :has_many || association[:kind] == :has_one
          # Default to nullify for safety
          options << "dependent: :nullify"
        end
        
        # Handle through option for has_many :through
        options << "through: :#{attrs[:through]}" if attrs[:through]
        
        # Handle source option for has_many :through
        options << "source: :#{attrs[:source]}" if attrs[:source]
        
        # Handle class_name option
        options << "class_name: '#{attrs[:class_name]}'" if attrs[:class_name]
        
        # Handle foreign_key option
        options << "foreign_key: :#{attrs[:foreign_key]}" if attrs[:foreign_key]
        
        # Handle optional for belongs_to (Rails 5+)
        options << "optional: #{attrs[:optional]}" if association[:kind] == :belongs_to && attrs.key?(:optional)
        
        # Handle polymorphic
        options << "polymorphic: true" if attrs[:polymorphic]
        
        # Handle as for polymorphic belongs_to
        options << "as: :#{attrs[:as]}" if attrs[:as]
        
        # Handle counter_cache
        if attrs[:counter_cache]
          counter_value = attrs[:counter_cache] == true ? "true" : ":#{attrs[:counter_cache]}"
          options << "counter_cache: #{counter_value}"
        end
        
        # Handle validate option
        options << "validate: #{attrs[:validate]}" if attrs.key?(:validate)
        
        # Handle autosave option
        options << "autosave: #{attrs[:autosave]}" if attrs.key?(:autosave)
        
        options
      end
      
      def generate_validations(f, model)
        # Add basic validations based on attribute types
        model.attributes.each do |attr_name, attr_type|
          case attr_type
          when :string, :text
            if attr_name.to_s == 'email'
              f.write("  validates :#{attr_name}, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }\n")
            elsif attr_name.to_s == 'name' || attr_name.to_s == 'title'
              f.write("  validates :#{attr_name}, presence: true\n")
            end
          when :integer, :decimal, :float
            if attr_name.to_s.end_with?('_count') || attr_name.to_s.end_with?('_amount')
              f.write("  validates :#{attr_name}, numericality: { greater_than_or_equal_to: 0 }\n")
            end
          end
        end
        
        # Add presence validations for belongs_to associations
        model.associations.each do |assoc|
          if assoc[:kind] == :belongs_to && !assoc[:attrs][:optional]
            f.write("  validates :#{assoc[:name]}_id, presence: true\n")
          end
        end
        
        f.write("\n") if model.attributes.any? || model.associations.any?
      end
      
      def generate_scopes(f, model)
        # Add common scopes based on attributes
        has_timestamps = model.attributes.keys.include?(:created_at) || 
                        model.attributes.keys.include?(:updated_at)
        
        if has_timestamps
          f.write("  scope :recent, -> { order(created_at: :desc) }\n")
        end
        
        if model.attributes.keys.include?(:active) || model.attributes.keys.include?(:status)
          status_field = model.attributes.keys.include?(:active) ? :active : :status
          if status_field == :active
            f.write("  scope :active, -> { where(active: true) }\n")
            f.write("  scope :inactive, -> { where(active: false) }\n")
          else
            f.write("  scope :active, -> { where(status: 'active') }\n")
            f.write("  scope :inactive, -> { where.not(status: 'active') }\n")
          end
        end
        
        f.write("\n") if has_timestamps || model.attributes.keys.include?(:active) || model.attributes.keys.include?(:status)
      end
      
      def generate_callbacks(f, model)
        # Add callback methods if needed based on model attributes
        needs_callbacks = false
        
        if model.attributes.keys.include?(:slug) && model.attributes.keys.include?(:name)
          f.write("  before_validation :generate_slug, if: -> { name_changed? || slug.blank? }\n\n")
          f.write("  private\n\n")
          f.write("  def generate_slug\n")
          f.write("    self.slug = name.to_s.parameterize\n")
          f.write("  end\n")
          needs_callbacks = true
        end
        
        f.write("\n") if needs_callbacks
      end
    end
  end
end 