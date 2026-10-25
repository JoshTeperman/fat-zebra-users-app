require "rails_helper"

RSpec.describe "Api::V1::UsersController", type: :request do
  let(:repository) { UserRepository.new }
  let(:user_attributes) { { first_name: "Mark", last_name: "Hamil", date_of_birth: "1990-12-10" } }
  let(:user_attributes_2) { { first_name: "Harrison", last_name: "Ford", date_of_birth: "1985-07-13" } }
  let(:serialized_user) { { "id" => 1, "first_name" => "Mark", "last_name" => "Hamil", "date_of_birth" => "1990-12-10" } }
  let(:serialized_user_2) { { "id" => 2, "first_name" => "Harrison", "last_name" => "Ford", "date_of_birth" => "1985-07-13" } }

  before { allow(UserRepository).to receive(:instance).and_return(repository) }

  describe "GET /api/v1/users" do
    context "when users are stored" do
      before do
        repository.create(user_attributes)
        repository.create(user_attributes_2)
        get "/api/v1/users"
      end

      it "returns the serialized users", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]).to eq([
          serialized_user,
          serialized_user_2
        ])
      end
    end

    context "when no users are stored" do
      before { get "/api/v1/users" }

      it "returns an empty list", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]).to eq([])
      end
    end
  end

  describe "POST /api/v1/users" do
    let(:params) { { user: user_attributes } }

    before { post "/api/v1/users", params: params, as: :json }

    it "creates the user", :aggregate_failures do
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["data"]).to eq(serialized_user)
      expect(repository.all.map(&:id)).to eq([ 1 ])
    end

    context "when the attributes aren't wrapped in a user object" do
      let(:params) { user_attributes }

      it "returns bad request" do
        expect(response).to have_http_status(:bad_request)
      end

      it "returns the error details" do
        expect(response.parsed_body["errors"]).to include(
          a_hash_including("code" => "parameter_missing", "field" => "user", "message" => "is required and must be a JSON object")
        )
      end
    end

    context "when the params includes attributes that aren't writable" do
      let(:params) { { user: user_attributes.merge(id: 99, admin: true) } }

      it "returns an unprocessable entity error" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns the error details" do
        expect(response.parsed_body["errors"]).to include(
          a_hash_including("code" => "unknown_field", "field" => "id", "message" => "is not a recognised field"),
          a_hash_including("code" => "unknown_field", "field" => "admin", "message" => "is not a recognised field")
        )
      end
    end

    context "when the attributes are invalid parameter types" do
      let(:params) { { user: user_attributes.merge(first_name: []) } }

      it "returns the validation errors", :aggregate_failures do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to contain_exactly(
          a_hash_including("code" => "invalid_type", "field" => "first_name", "message" => "must be a string")
        )
      end

      it "doesn't create the user" do
        expect(repository.all).to be_empty
      end
    end

    context "when the attributes fail user validations" do
      let(:params) { { user: user_attributes.merge(first_name: "", date_of_birth: "10/12/1990") } }

      it "returns the validation errors", :aggregate_failures do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to contain_exactly(
          a_hash_including("code" => "blank", "field" => "first_name", "message" => "can't be blank"),
          a_hash_including("code" => "invalid_format", "field" => "date_of_birth", "message" => "must be a date in YYYY-MM-DD format")
        )
      end

      it "doesn't create the user" do
        expect(repository.all).to be_empty
      end
    end

    context "when the user object is missing" do
      let(:params) { { person: user_attributes } }

      it "returns bad request" do
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when the user object is null" do
      let(:params) { { user: nil } }

      it "returns bad request" do
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when the user object is empty" do
      let(:params) { { user: {} } }

      it "returns bad request" do
        expect(response).to have_http_status(:bad_request)
      end
    end

    [ 123, true ].each do |value|
      context "when a name is a #{value.class}" do
        let(:params) { { user: user_attributes.merge(first_name: value) } }

        it "returns the validation errors", :aggregate_failures do
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body["errors"]).to contain_exactly(
            a_hash_including("code" => "not_a_string", "field" => "first_name", "message" => "must be a string")
          )
        end

        it "doesn't create the user" do
          expect(repository.all).to be_empty
        end
      end
    end
  end

  describe "malformed JSON" do
    before do
      post "/api/v1/users", params: '{"user":{"first_name":', headers: { "CONTENT_TYPE" => "application/json" }
    end

    it "returns bad request with the error details", :aggregate_failures do
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["errors"]).to contain_exactly(
        a_hash_including("code" => "malformed_json", "field" => "body", "message" => "is not valid JSON")
      )
    end
  end

  describe "PATCH /api/v1/users/:id" do
    let(:params) { { user: { first_name: "Carrie" } } }

    before do
      repository.create(user_attributes)
      patch "/api/v1/users/1", params: params, as: :json
    end

    it "updates the user", :aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to eq(serialized_user.merge("first_name" => "Carrie"))
      expect(repository.all.map(&:first_name)).to eq([ "Carrie" ])
    end

    context "when user does not exist" do
      before { patch "/api/v1/users/999", params: params, as: :json }

      it "returns not found with the error details", :aggregate_failures do
        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["errors"]).to contain_exactly(
          a_hash_including("code" => "not_found", "field" => "id", "message" => "does not match an existing record")
        )
      end
    end

    context "when the changes are invalid" do
      let(:params) { { user: { date_of_birth: "10/12/1990" } } }

      it "returns the validation errors", :aggregate_failures do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to contain_exactly(
          a_hash_including("code" => "invalid_format", "field" => "date_of_birth", "message" => "must be a date in YYYY-MM-DD format")
        )
      end

      it "leaves the user unchanged" do
        expect(repository.all.first.date_of_birth).to eq(Date.new(1990, 12, 10))
      end
    end

    context "when the params includes attributes that aren't writable" do
      let(:params) { { user: { id: 99, admin: true } } }

      it "returns unprocessable entity status" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns an error for the unknown fields" do
        expect(response.parsed_body["errors"]).to include(
          a_hash_including("code" => "unknown_field", "field" => "id"),
          a_hash_including("code" => "unknown_field", "field" => "admin")
        )
      end
    end

    context "when the user object is missing" do
      let(:params) { {} }

      it "returns bad request" do
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
