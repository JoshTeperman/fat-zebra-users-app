require "rails_helper"

RSpec.describe "API authentication", type: :request do
  shared_examples "an unauthorized request" do
    it "returns 401 with the error body and a Bearer challenge", :aggregate_failures do
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq(
        "errors" => [ { "code" => "unauthorized", "field" => "authorization", "message" => "a valid bearer token is required" } ]
      )
      expect(response.headers["WWW-Authenticate"]).to eq("Bearer")
    end
  end

  describe "GET /api/v1/users" do
    before { get "/api/v1/users", headers: }

    context "without an Authorization header" do
      let(:headers) { {} }

      it_behaves_like "an unauthorized request"
    end

    context "with a valid token sent with the Basic scheme" do
      let(:headers) do
        { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("reader", ApiClientHelpers::CLIENTS[:reader][:token]) }
      end

      it_behaves_like "an unauthorized request"
    end

    context "with an empty bearer token" do
      let(:headers) { { "Authorization" => "Bearer " } }

      it_behaves_like "an unauthorized request"
    end

    context "with an unknown bearer token" do
      let(:headers) { { "Authorization" => "Bearer wrong" } }

      it_behaves_like "an unauthorized request"
    end

    context "with a valid bearer token" do
      let(:headers) { auth_headers(:reader) }

      it "reaches the action", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("data" => [])
      end
    end
  end

  context "when the body is malformed JSON and there is no token" do
    before { post "/api/v1/users", params: '{"user":', headers: { "CONTENT_TYPE" => "application/json" } }

    it_behaves_like "an unauthorized request"
  end

  describe "every /api/v1 route" do
    api_routes = Rails.application.routes.routes
      .map { |route| [ route.verb, route.path.spec.to_s.delete_suffix("(.:format)") ] }
      .select { |_verb, path| path.start_with?("/api/v1/") }

    it "includes the users routes" do
      expect(api_routes).to include([ "GET", "/api/v1/users" ], [ "POST", "/api/v1/users" ], [ "PATCH", "/api/v1/users/:id" ])
    end

    api_routes.each do |verb, path|
      it "rejects #{verb} #{path} without a token" do
        process verb.downcase.to_sym, path.gsub(/:\w+/, "1")

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
