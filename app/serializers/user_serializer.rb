class UserSerializer
  def self.call(user)
    {
      id: user.id,
      first_name: user.first_name,
      last_name: user.last_name,
      date_of_birth: user.date_of_birth.iso8601
    }
  end
end
