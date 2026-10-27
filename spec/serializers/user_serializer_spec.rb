require "rails_helper"

RSpec.describe UserSerializer do
  subject(:serialized) { described_class.call(user) }

  let(:user) do
    User.new(
      id: 1,
      first_name: "Mark",
      last_name: "Hamill",
      date_of_birth: "1990-12-10"
    )
  end

  it "serializes the user's attributes" do
    expect(serialized).to eq(
      id: 1,
      first_name: "Mark",
      last_name: "Hamill",
      date_of_birth: "1990-12-10"
    )
  end
end
