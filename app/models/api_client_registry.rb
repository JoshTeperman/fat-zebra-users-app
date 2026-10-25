class ApiClientRegistry
  class ConfigurationError < StandardError; end

  TOKEN_DIGEST = /\A[0-9a-f]{64}\z/

  class << self
    attr_reader :instance

    def from_json(json)
      raise ConfigurationError, "API_CLIENTS is not set" if json.blank?

      entries = JSON.parse(json)
      raise ConfigurationError, "API_CLIENTS must be a non-empty JSON array" unless entries.is_a?(Array) && entries.any?

      new(entries.each_with_index.map { |entry, index| build_client(entry, index) })
    rescue JSON::ParserError
      raise ConfigurationError, "API_CLIENTS is not valid JSON"
    end

    private

    def build_client(entry, index)
      token_digest = entry["token_digest"] if entry.is_a?(Hash)
      unless token_digest.is_a?(String) && token_digest.match?(TOKEN_DIGEST)
        raise ConfigurationError, "API_CLIENTS entry #{index} needs a token_digest of 64 lowercase hex characters"
      end

      ApiClient.new(name: entry["name"], token_digest:, scopes: Array(entry["scopes"]))
    end
  end

  def initialize(clients)
    @clients = clients
  end

  # Compares against every client, without stopping at a match, so the time taken
  # doesn't reveal which client matched.
  def find_by_token(token)
    digest = Digest::SHA256.hexdigest(token)

    @clients.reduce(nil) do |match, client|
      ActiveSupport::SecurityUtils.secure_compare(client.token_digest, digest) ? client : match
    end
  end

  # Built when the class loads, like UserRepository.instance. Specs stub it instead.
  @instance = from_json(ENV["API_CLIENTS"]) unless Rails.env.test?
end
