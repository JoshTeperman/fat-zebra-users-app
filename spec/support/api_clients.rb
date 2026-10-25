module ApiClientHelpers
  CLIENTS = {
    reader: { token: "fz-dev-reader-NOT-A-SECRET-0001", scopes: [ "users:read" ] },
    admin: { token: "fz-dev-admin-NOT-A-SECRET-0002", scopes: [ "users:read", "users:write" ] }
  }.freeze

  def self.registry
    ApiClientRegistry.from_json(
      CLIENTS.map { |name, client| { name:, token_digest: Digest::SHA256.hexdigest(client[:token]), scopes: client[:scopes] } }.to_json
    )
  end

  def auth_headers(client = :admin)
    { "Authorization" => "Bearer #{CLIENTS.fetch(client)[:token]}" }
  end
end

RSpec.configure do |config|
  config.include ApiClientHelpers, type: :request

  config.before(type: :request) do
    allow(ApiClientRegistry).to receive(:instance).and_return(ApiClientHelpers.registry)
  end
end
