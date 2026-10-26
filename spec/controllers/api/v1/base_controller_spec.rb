require "rails_helper"

RSpec.describe Api::V1::BaseController, type: :controller do
  controller do
    def self.controller_name = "widgets"

    def index = head(:ok)
    def export = head(:ok)
  end

  let(:token) { "widgets-reader-token" }
  let(:scopes) { [ "widgets:read" ] }

  before do
    routes.draw do
      get "widgets" => "api/v1/base#index"
      get "widgets/export" => "api/v1/base#export"
    end
    registry = ApiClientRegistry.from_json([ { name: "widgets-reader", token_digest: Digest::SHA256.hexdigest(token), scopes: } ].to_json)
    allow(ApiClientRegistry).to receive(:instance).and_return(registry)
    request.headers["Authorization"] = "Bearer #{token}"
  end

  it "allows a client with the scope named after the controller and action" do
    get :index

    expect(response).to have_http_status(:ok)
  end

  context "when the client doesn't have that scope" do
    let(:scopes) { [ "users:read" ] }

    it "returns 403 naming the required scope", :aggregate_failures do
      get :index

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to eq(
        "errors" => [ { "code" => "forbidden", "field" => "scope", "message" => "requires the widgets:read scope" } ]
      )
    end
  end

  it "denies an action that isn't a standard read or write action", :aggregate_failures do
    get :export

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body).to eq(
      "errors" => [ { "code" => "forbidden", "field" => "scope", "message" => "is not granted to any scope" } ]
    )
  end
end
