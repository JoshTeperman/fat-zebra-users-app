class ApiClientRegistry
  TOKEN_DIGEST_REGEX = /\A[0-9a-f]{64}\z/

  class << self
    attr_accessor :instance

    def from_json(config)
      configured_clients = JSON.parse(config)
      raise "API_CLIENTS not found" unless configured_clients.is_a?(Array) && configured_clients.present?

      clients = configured_clients.map { build_client(_1) }
      new(clients)
    rescue JSON::ParserError => e
      raise "Error parsing API_CLIENTS json config: #{e.message}"
    end

    private

    ApiClient = Data.define(:name, :token_digest, :scopes)
    def build_client(client)
      token_digest = client["token_digest"] if client.is_a?(Hash)
      raise "API_CLIENTS #{client["name"]} token is invalid" unless token_digest.is_a?(String) && token_digest.match?(TOKEN_DIGEST_REGEX)

      ApiClient.new(name: client["name"], token_digest:, scopes: Array(client["scopes"]))
    end
  end

  def initialize(clients)
    @clients = clients
  end

  def find_by_token(token)
    clients.find do |client|
      ActiveSupport::SecurityUtils.secure_compare(
        client.token_digest,
        Digest::SHA256.hexdigest(token)
      )
    end
  end

  private

  attr_reader :clients
end
