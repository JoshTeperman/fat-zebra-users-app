Rails.application.config.to_prepare do
  ApiClientRegistry.instance = ApiClientRegistry.from_json(ENV.fetch("API_CLIENTS", "")) unless Rails.env.test?
end
