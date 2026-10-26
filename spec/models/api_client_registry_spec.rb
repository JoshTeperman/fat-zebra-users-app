require "rails_helper"

RSpec.describe ApiClientRegistry do
  subject(:registry) { described_class.from_json(json_config) }

  let(:reader_token) { "test-reader-token" }
  let(:admin_token) { "test-admin-token" }
  let(:json_config) do
    [
      { name: "reader", token_digest: Digest::SHA256.hexdigest(reader_token), scopes: [ "users:read" ] },
      { name: "admin", token_digest: Digest::SHA256.hexdigest(admin_token), scopes: [ "users:read", "users:write" ] }
    ].to_json
  end

  describe "#find_by_token" do
    it "returns the client with matching token" do
      expect(registry.find_by_token(admin_token)).to have_attributes(name: "admin", scopes: [ "users:read", "users:write" ])
    end

    it "returns nil for an unregistered client token" do
      expect(registry.find_by_token("unknown-token")).to be_nil
    end

    it "returns nil for a blank token" do
      expect(registry.find_by_token("")).to be_nil
    end
  end

  describe ".from_json" do
    it "initializes a client for each api client entry in the given config" do
      expect(described_class.from_json(json_config).send(:clients)).to include(
        have_attributes(name: "reader", scopes: [ "users:read" ]),
        have_attributes(name: "admin", scopes: [ "users:read", "users:write" ])
      )
    end

    context "when the config isn't valid JSON" do
      let(:json_config) { "[{" }

      it "raises an error for invalid JSON" do
        expect { described_class.from_json(json_config) }.to raise_error(/Error parsing API_CLIENTS json config/)
      end
    end

    context "when there are no clients" do
      let(:json_config) { "[]" }

      it "raises an error for no clients" do
        expect { described_class.from_json(json_config) }.to raise_error("API_CLIENTS not found")
      end
    end

    context "when a client's token digest is invalid" do
      let(:json_config) { [ { name: "admin", token_digest: "abc123", scopes: [ "users:read", "users:write" ] } ].to_json }

      it "raises an error for invalid token digest" do
        expect { described_class.from_json(json_config) }.to raise_error("API_CLIENTS admin token is invalid")
      end
    end
  end
end
