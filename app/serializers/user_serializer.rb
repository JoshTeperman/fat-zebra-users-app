class UserSerializer
  TIMESTAMP_PRECISION = 3

  def self.call(user)
    {
      id: user.id,
      first_name: user.first_name,
      last_name: user.last_name,
      date_of_birth: user.date_of_birth.iso8601,
      created_at: user.created_at.iso8601(TIMESTAMP_PRECISION),
      updated_at: user.updated_at.iso8601(TIMESTAMP_PRECISION)
    }
  end
end
