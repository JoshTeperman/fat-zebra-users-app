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
      id: a_string_matching(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/),
      created_at: be_a(ActiveSupport::TimeWithZone),
      updated_at: be_a(ActiveSupport::TimeWithZone),
      first_name: "Ada",
      last_name: "Lovelace",
      date_of_birth: Date.new(1990, 12, 10)
    )
  end

  it "generates a different id for each user" do
    expect(user.id).not_to eq(described_class.new(attributes).id)
  end

  describe "timestamps" do
    before { freeze_time }

    it "sets created_at and updated_at to the current time" do
      expect(user).to have_attributes(created_at: Time.current, updated_at: Time.current)
    end

    context "when created_at is provided" do
      let(:created_at) { 1.day.ago }
      let(:attributes) { super().merge(created_at:) }

      it "defaults updated_at to created_at" do
        expect(user).to have_attributes(created_at:, updated_at: created_at)
      end
    end

    context "when both timestamps are provided" do
      let(:created_at) { 2.days.ago }
      let(:updated_at) { 1.day.ago }
      let(:attributes) { super().merge(created_at:, updated_at:) }

      it "keeps the provided timestamps" do
        expect(user).to have_attributes(created_at:, updated_at:)
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
      context "when #{name_field} is missing", :aggregate_failures do
        let(:attributes) { super().except(name_field) }

        it { is_expected.not_to be_valid }
        it { expect(user.errors).to be_of_kind(name_field, :blank) }
      end

      context "when #{name_field} is only whitespace", :aggregate_failures do
        let(:attributes) { super().merge(name_field => "   ") }

        it { is_expected.not_to be_valid }
        it { expect(user.errors).to be_of_kind(name_field, :blank) }
      end

      context "when #{name_field} is longer than MAX_NAME_LENGTH", :aggregate_failures do
        let(:attributes) { super().merge(name_field => "a" * (User::MAX_NAME_LENGTH + 1)) }

        it { is_expected.not_to be_valid }
        it { expect(user.errors).to be_of_kind(name_field, :too_long) }
      end

      context "when #{name_field} is exactly MAX_NAME_LENGTH" do
        let(:attributes) { super().merge(name_field => "a" * User::MAX_NAME_LENGTH) }

        it { is_expected.to be_valid }
      end

      context "when #{name_field} is not a string", :aggregate_failures do
        let(:attributes) { super().merge(name_field => 123) }

        it { is_expected.not_to be_valid }
        it { expect(user.errors).to be_of_kind(name_field, :not_a_string) }
      end
    end

    context "when date_of_birth is missing", :aggregate_failures do
      let(:attributes) { super().except(:date_of_birth) }

      it { is_expected.not_to be_valid }
      it { expect(user.errors).to be_of_kind(:date_of_birth, :blank) }
    end

    context "when date_of_birth is an empty string", :aggregate_failures do
      let(:attributes) { super().merge(date_of_birth: "") }

      it { is_expected.not_to be_valid }
      it { expect(user.errors).to be_of_kind(:date_of_birth, :blank) }
    end

    context "when date_of_birth is not in ISO 8601 format", :aggregate_failures do
      let(:attributes) { super().merge(date_of_birth: "10/12/1990") }

      it { is_expected.not_to be_valid }
      it { expect(user.errors).to be_of_kind(:date_of_birth, :invalid_format) }
    end

    context "when date_of_birth is not a real calendar date", :aggregate_failures do
      let(:attributes) { super().merge(date_of_birth: "1990-02-30") }

      it { is_expected.not_to be_valid }
      it { expect(user.errors).to be_of_kind(:date_of_birth, :invalid_format) }
    end

    context "when date_of_birth is not a string or date", :aggregate_failures do
      let(:attributes) { super().merge(date_of_birth: 19901210) }

      it { is_expected.not_to be_valid }
      it { expect(user.errors).to be_of_kind(:date_of_birth, :invalid_format) }
    end

    context "when date_of_birth is a Date" do
      let(:attributes) { super().merge(date_of_birth: Date.new(1990, 12, 10)) }

      it { is_expected.to be_valid }
    end

    context "when date_of_birth is in the future", :aggregate_failures do
      let(:attributes) { super().merge(date_of_birth: Date.current.tomorrow.iso8601) }

      it { is_expected.not_to be_valid }
      it { expect(user.errors).to be_of_kind(:date_of_birth, :in_the_future) }
    end

    context "when date_of_birth is today" do
      let(:attributes) { super().merge(date_of_birth: Date.current.iso8601) }

      it { is_expected.to be_valid }
    end

    context "when date_of_birth is earlier than MINIMUM_DATE_OF_BIRTH", :aggregate_failures do
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
