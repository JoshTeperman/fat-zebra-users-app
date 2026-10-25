require "rails_helper"

RSpec.describe ApiClientRegistry do
  subject(:registry) { described_class.from_json(api_clients) }

  let(:reader_token) { "test-reader-token" }
  let(:admin_token) { "test-admin-token" }
  let(:api_clients) do
    [
      { name: "reader", token_digest: Digest::SHA256.hexdigest(reader_token), scopes: [ "users:read" ] },
      { name: "admin", token_digest: Digest::SHA256.hexdigest(admin_token), scopes: [ "users:read", "users:write" ] }
    ].to_json
  end

  describe "#find_by_token" do
    it "returns the client whose digest matches the token" do
      expect(registry.find_by_token(admin_token)).to have_attributes(name: "admin", scopes: [ "users:read", "users:write" ])
    end

    it "tells clients apart" do
      expect(registry.find_by_token(reader_token)).to have_attributes(name: "reader", scopes: [ "users:read" ])
    end

    it "returns nil for an unknown token" do
      expect(registry.find_by_token("unknown-token")).to be_nil
    end

    it "returns nil for a token that is the digest itself" do
      expect(registry.find_by_token(Digest::SHA256.hexdigest(admin_token))).to be_nil
    end

    it "returns nil for a blank token" do
      expect(registry.find_by_token("")).to be_nil
    end
  end

  describe ".from_json" do
    def expect_configuration_error(json, message)
      expect { described_class.from_json(json) }.to raise_error(ApiClientRegistry::ConfigurationError, message)
    end

    it "rejects a missing value" do
      expect_configuration_error(nil, "API_CLIENTS is not set")
    end

    it "rejects a blank value" do
      expect_configuration_error(" ", "API_CLIENTS is not set")
    end

    it "rejects invalid JSON" do
      expect_configuration_error("[{", "API_CLIENTS is not valid JSON")
    end

    it "rejects an empty list" do
      expect_configuration_error("[]", "API_CLIENTS must be a non-empty JSON array")
    end

    it "rejects a value that isn't a list" do
      expect_configuration_error({ name: "admin" }.to_json, "API_CLIENTS must be a non-empty JSON array")
    end

    it "rejects a digest with the wrong length" do
      expect_configuration_error(
        [ { name: "admin", token_digest: "abc123", scopes: [] } ].to_json,
        "API_CLIENTS entry 0 needs a token_digest of 64 lowercase hex characters"
      )
    end

    it "rejects a digest that isn't lowercase hex" do
      expect_configuration_error(
        [ { name: "admin", token_digest: Digest::SHA256.hexdigest(admin_token).upcase, scopes: [] } ].to_json,
        "API_CLIENTS entry 0 needs a token_digest of 64 lowercase hex characters"
      )
    end

    it "names the entry that is wrong" do
      expect_configuration_error(
        [ JSON.parse(api_clients).first, { name: "admin", scopes: [] } ].to_json,
        "API_CLIENTS entry 1 needs a token_digest of 64 lowercase hex characters"
      )
    end

    it "rejects an entry that isn't an object" do
      expect_configuration_error([ "admin" ].to_json, "API_CLIENTS entry 0 needs a token_digest of 64 lowercase hex characters")
    end
  end
end
