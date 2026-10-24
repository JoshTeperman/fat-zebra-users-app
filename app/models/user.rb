class User
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Attributes::Normalization

  MAX_NAME_LENGTH = 50
  MINIMUM_DATE_OF_BIRTH = Date.new(1900, 1, 1)
  ISO_8601_DATE = /\A\d{4}-\d{2}-\d{2}\z/

  attribute :id, :string, default: -> { SecureRandom.uuid }
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :date_of_birth, :date

  normalizes :first_name, :last_name, with: ->(name) { name.is_a?(String) ? name.strip : name }

  validates :first_name, :last_name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validate :name_fields_must_be_strings

  validate :date_of_birth_must_be_reasonable_iso8601_date

  private

  def name_fields_must_be_strings
    %i[first_name last_name].each do |attribute|
      raw_value = attribute_before_type_cast(attribute)
      next if raw_value.nil? || raw_value.is_a?(String)

      errors.add(attribute, :not_a_string)
    end
  end

  def date_of_birth_must_be_reasonable_iso8601_date
    raw_value = attribute_before_type_cast(:date_of_birth)

    if raw_value.nil? || raw_value.to_s.strip.empty?
      errors.add(:date_of_birth, :blank)
    elsif !iso8601_date_format?(raw_value)
      errors.add(:date_of_birth, :invalid_format)
    elsif date_of_birth > Date.current
      errors.add(:date_of_birth, :in_the_future)
    elsif date_of_birth < MINIMUM_DATE_OF_BIRTH
      errors.add(:date_of_birth, :too_old, date: MINIMUM_DATE_OF_BIRTH)
    end
  end

  def iso8601_date_format?(raw_value)
    return true if raw_value.is_a?(Date)

    raw_value.is_a?(String) && raw_value.match?(ISO_8601_DATE) && date_of_birth.present?
  end

  def attribute_before_type_cast(attribute)
    @attributes[attribute.to_s].value_before_type_cast
  end
end
