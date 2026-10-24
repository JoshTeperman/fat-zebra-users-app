require "rails_helper"

RSpec.describe UserSerializer do
  subject(:serialized) { described_class.call(user) }

  let(:user) do
    User.new(
      id: "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
      first_name: "Ada",
      last_name: "Lovelace",
      date_of_birth: "1990-12-10",
      created_at: Time.utc(2026, 10, 24, 1, 2, 3.456r),
      updated_at: Time.utc(2026, 10, 25, 4, 5, 6.789r)
    )
  end

  it "serializes the user's attributes" do
    expect(serialized).to eq(
      id: "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
      first_name: "Ada",
      last_name: "Lovelace",
      date_of_birth: "1990-12-10",
      created_at: "2026-10-24T01:02:03.456Z",
      updated_at: "2026-10-25T04:05:06.789Z"
    )
  end
end
