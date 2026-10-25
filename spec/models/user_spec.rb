require "rails_helper"

RSpec.describe User do
  subject(:user) { described_class.new(attributes) }

  let(:attributes) do
    {
      first_name: "Ada",
      last_name: "Lovelace",
      date_of_birth: "1990-12-10"
    }
  end

  it { is_expected.to be_valid }

  it "has expected attributes" do
    expect(user).to have_attributes(
      id: nil,
      first_name: "Ada",
      last_name: "Lovelace",
      date_of_birth: Date.new(1990, 12, 10)
    )
  end

  it "allows only the user's details to be written" do
    expect(User::WRITABLE_ATTRIBUTES).to eq(%i[first_name last_name date_of_birth])
  end

  describe "id" do
    context "when id is provided" do
      let(:attributes) { super().merge(id: 1) }

      it "keeps the provided id" do
        expect(user.id).to eq(1)
      end
    end

    context "when id is provided as a string" do
      let(:attributes) { super().merge(id: "1") }

      it "casts it to an integer" do
        expect(user.id).to eq(1)
      end
    end
  end

  describe "normalization" do
    context "when names have surrounding whitespace" do
      let(:attributes) { super().merge(first_name: "  Ada ", last_name: " Lovelace  ") }

      it "strips the whitespace" do
        expect(user).to have_attributes(first_name: "Ada", last_name: "Lovelace")
      end
    end
  end

  describe "validations" do
    before { user.validate }

    %i[first_name last_name].each do |name_field|
      context "when #{name_field} is missing" do
        let(:attributes) { super().except(name_field) }

        it { is_expected.not_to be_valid }
        it { expect(user.errors).to be_of_kind(name_field, :blank) }
      end

      context "when #{name_field} is only whitespace" do
        let(:attributes) { super().merge(name_field => "   ") }

        it { is_expected.not_to be_valid }
        it { expect(user.errors).to be_of_kind(name_field, :blank) }
      end

      context "when #{name_field} is longer than MAX_NAME_LENGTH" do
        let(:attributes) { super().merge(name_field => "a" * (User::MAX_NAME_LENGTH + 1)) }

        it { is_expected.not_to be_valid }
        it { expect(user.errors).to be_of_kind(name_field, :too_long) }
      end

      context "when #{name_field} is exactly MAX_NAME_LENGTH" do
        let(:attributes) { super().merge(name_field => "a" * User::MAX_NAME_LENGTH) }

        it { is_expected.to be_valid }
      end

      context "when #{name_field} is not a string" do
        let(:attributes) { super().merge(name_field => 123) }

        it { is_expected.not_to be_valid }
        it { expect(user.errors).to be_of_kind(name_field, :not_a_string) }
      end
    end

    context "when date_of_birth is missing" do
      let(:attributes) { super().except(:date_of_birth) }

      it { is_expected.not_to be_valid }
      it { expect(user.errors).to be_of_kind(:date_of_birth, :blank) }
    end

    context "when date_of_birth is an empty string" do
      let(:attributes) { super().merge(date_of_birth: "") }

      it { is_expected.not_to be_valid }
      it { expect(user.errors).to be_of_kind(:date_of_birth, :blank) }
    end

    context "when date_of_birth is not in ISO 8601 format" do
      let(:attributes) { super().merge(date_of_birth: "10/12/1990") }

      it { is_expected.not_to be_valid }
      it { expect(user.errors).to be_of_kind(:date_of_birth, :invalid_format) }
    end

    context "when date_of_birth is not a real calendar date" do
      let(:attributes) { super().merge(date_of_birth: "1990-02-30") }

      it { is_expected.not_to be_valid }
      it { expect(user.errors).to be_of_kind(:date_of_birth, :invalid_format) }
    end

    context "when date_of_birth is not a string or date" do
      let(:attributes) { super().merge(date_of_birth: 19901210) }

      it { is_expected.not_to be_valid }
      it { expect(user.errors).to be_of_kind(:date_of_birth, :invalid_format) }
    end

    context "when date_of_birth is a Date" do
      let(:attributes) { super().merge(date_of_birth: Date.new(1990, 12, 10)) }

      it { is_expected.to be_valid }
    end

    context "when date_of_birth is in the future" do
      let(:attributes) { super().merge(date_of_birth: Date.current.tomorrow.iso8601) }

      it { is_expected.not_to be_valid }
      it { expect(user.errors).to be_of_kind(:date_of_birth, :in_the_future) }
    end

    context "when date_of_birth is today" do
      let(:attributes) { super().merge(date_of_birth: Date.current.iso8601) }

      it { is_expected.to be_valid }
    end

    context "when date_of_birth is earlier than MINIMUM_DATE_OF_BIRTH" do
      let(:attributes) { super().merge(date_of_birth: User::MINIMUM_DATE_OF_BIRTH.yesterday.iso8601) }

      it { is_expected.not_to be_valid }
      it { expect(user.errors).to be_of_kind(:date_of_birth, :too_old) }
    end

    context "when date_of_birth is MINIMUM_DATE_OF_BIRTH" do
      let(:attributes) { super().merge(date_of_birth: User::MINIMUM_DATE_OF_BIRTH.iso8601) }

      it { is_expected.to be_valid }
    end
  end
end
