require "rails_helper"

RSpec.describe Api::V1::BaseController, type: :controller do
  controller do
    def index = head(:ok)
  end

  before do
    allow(ApiClientRegistry).to receive(:instance).and_return(ApiClientHelpers.registry)
    request.headers["Authorization"] = "Bearer #{ApiClientHelpers::CLIENTS[:admin][:token]}"
  end

  it "denies an action that doesn't declare a scope", :aggregate_failures do
    get :index

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body).to eq(
      "errors" => [ { "code" => "forbidden", "field" => "scope", "message" => "is not granted to any scope" } ]
    )
  end
end
