require "rails_helper"

RSpec.describe "API authorization", type: :request do
  let(:repository) { UserRepository.new }
  let(:user_attributes) { { first_name: "Mark", last_name: "Hamil", date_of_birth: "1990-12-10" } }

  before do
    allow(UserRepository).to receive(:instance).and_return(repository)
    repository.create(user_attributes)
  end

  def send_request(action, client, params: { user: { first_name: "Luke" } }, id: 1)
    case action
    when :index then get "/api/v1/users", headers: auth_headers(client)
    when :create then post "/api/v1/users", params: { user: user_attributes }, headers: auth_headers(client), as: :json
    when :update then patch "/api/v1/users/#{id}", params:, headers: auth_headers(client), as: :json
    end
  end

  shared_examples "a forbidden request" do |scope|
    it "returns 403 naming the missing scope", :aggregate_failures do
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to eq(
        "errors" => [ { "code" => "forbidden", "field" => "scope", "message" => "requires the #{scope} scope" } ]
      )
    end
  end

  {
    reader: { index: :ok, create: :forbidden, update: :forbidden },
    writer: { index: :forbidden, create: :created, update: :ok }
  }.each do |client, expected_statuses|
    context "with the #{client} token" do
      expected_statuses.each do |action, status|
        it "returns #{status} for #{action}" do
          send_request(action, client)

          expect(response).to have_http_status(status)
        end
      end
    end
  end

  context "when the reader creates a user" do
    before { send_request(:create, :reader) }

    it_behaves_like "a forbidden request", "users:write"
  end

  context "when the writer lists users" do
    before { send_request(:index, :writer) }

    it_behaves_like "a forbidden request", "users:read"
  end

  context "when the reader sends an invalid body" do
    before { send_request(:update, :reader, params: { user: { first_name: [ "Luke" ], id: 2 } }) }

    it_behaves_like "a forbidden request", "users:write"
  end

  context "when the reader sends malformed JSON" do
    before { post "/api/v1/users", params: '{"user":', headers: auth_headers(:reader).merge("CONTENT_TYPE" => "application/json") }

    it_behaves_like "a forbidden request", "users:write"
  end

  context "when the reader updates a user that doesn't exist" do
    before { send_request(:update, :reader, id: 999) }

    it_behaves_like "a forbidden request", "users:write"
  end

  context "when a write is forbidden" do
    it "doesn't create or change users" do
      expect {
        send_request(:create, :reader)
        send_request(:update, :reader)
      }.not_to change { repository.all.map(&:attributes) }
    end
  end
end
