# Development doesn't eager-load, so load the registry at boot (and after each reload)
# to stop the app from starting with a missing or invalid API_CLIENTS.
Rails.application.config.to_prepare { ApiClientRegistry.instance }
