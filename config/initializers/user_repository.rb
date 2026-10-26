Rails.application.config.to_prepare do
  UserRepository.instance = UserRepository.new
end
