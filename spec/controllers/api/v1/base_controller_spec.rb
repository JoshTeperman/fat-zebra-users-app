require "rails_helper"

RSpec.describe Api::V1::BaseController, type: :controller do
  controller do
    def self.controller_name = "widgets"

    def index = head(:ok)
    def export = head(:ok)
  end

  before do
    routes.draw do
      get "widgets" => "api/v1/base#index"
      get "widgets/export" => "api/v1/base#export"
    end
    allow(ApiClientRegistry).to receive(:instance).and_return(ApiClientHelpers.registry)
    request.headers["Authorization"] = "Bearer #{ApiClientHelpers::CLIENTS[:reader][:token]}"
  end

  it "requires the scope named after the controller and action", :aggregate_failures do
    get :index

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body).to eq(
      "errors" => [ { "code" => "forbidden", "field" => "scope", "message" => "requires the widgets:read scope" } ]
    )
  end

  it "denies an action that isn't a standard read or write action", :aggregate_failures do
    get :export

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body).to eq(
      "errors" => [ { "code" => "forbidden", "field" => "scope", "message" => "is not granted to any scope" } ]
    )
  end
end
