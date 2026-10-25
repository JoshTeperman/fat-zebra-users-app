require "rails_helper"

RSpec.describe UserRepository do
  subject(:repository) { described_class.new }

  let(:user_attributes) do
    {
      first_name: "Mark",
      last_name: "Hamil",
      date_of_birth: "1990-12-10"
    }
  end

  describe ".instance" do
    it "shares stored users between accesses" do
      user = described_class.instance.create(user_attributes)
      expect(described_class.instance.all.map(&:id)).to include(user.id)
    end
  end

  describe "#all" do
    subject { repository.all }

    it "returns an empty list when no users are stored" do
      expect(subject).to eq([])
    end

    context "when users are already stored" do
      before do
        repository.create(user_attributes)
        repository.create(user_attributes.merge(first_name: "Carrie", last_name: "Fisher"))
      end

      it "returns the users in the order they were created" do
        expect(subject.map { |user| [ user.id, user.first_name ] }).to eq([ [ 1, "Mark" ], [ 2, "Carrie" ] ])
      end

      it "returns copies, so changing a user doesn't change the store" do
        subject.first.first_name << "Changed"

        expect(repository.all.first.first_name).to eq("Mark")
      end
    end
  end

  describe "#create" do
    subject { repository.create(user_attributes) }

    it "returns the saved user with the first id" do
      expect(subject).to have_attributes(id: 1, first_name: "Mark", errors: be_empty)
    end

    it "stores the user" do
      subject
      expect(repository.all.map(&:id)).to eq([ 1 ])
    end

    it "doesn't expose stored attributes through the returned user" do
      subject.first_name << "Changed"
      expect(repository.all.first.first_name).to eq("Mark")
    end

    it "assigns increasing ids" do
      subject
      expect(repository.create(user_attributes).id).to eq(2)
    end

    context "when an id is provided" do
      let(:user_attributes) { super().merge(id: 99) }

      it "ignores it and assigns the next id" do
        expect(subject.id).to eq(1)
      end
    end

    context "when the attributes include ones that aren't writable" do
      let(:user_attributes) { super().merge(admin: true) }

      it "ignores them and saves the user" do
        expect(subject).to have_attributes(id: 1, first_name: "Mark")
      end
    end

    context "when the attributes are unpermitted params" do
      let(:user_attributes) { ActionController::Parameters.new(super()) }

      it "raises" do
        expect { subject }.to raise_error(ActionController::UnfilteredParameters)
      end
    end

    context "when the attributes are invalid" do
      let(:user_attributes) { super().except(:first_name) }

      it "returns the user with errors and no id", :aggregate_failures do
        expect(subject.id).to be_nil
        expect(subject.errors[:first_name]).to include("can't be blank")
      end

      it "doesn't store the user" do
        subject

        expect(repository.all).to be_empty
      end

      it "doesn't use up an id" do
        subject

        expect(repository.create(user_attributes.merge(first_name: "Mark")).id).to eq(1)
      end
    end
  end

  describe "#update" do
    subject { repository.update(id, changes) }

    let!(:existing) { repository.create(user_attributes) }
    let(:id) { existing.id }
    let(:changes) { { first_name: "Harrison" } }

    it "returns the updated user" do
      expect(subject).to have_attributes(id: existing.id, first_name: "Harrison", last_name: "Hamil", errors: be_empty)
    end

    it "stores the changes" do
      subject

      expect(repository.all.first.first_name).to eq("Harrison")
    end

    it "doesn't expose stored attributes throught the returned user" do
      subject.first_name << "Changed"

      expect(repository.all.first.first_name).to eq("Harrison")
    end

    context "when the id is a string" do
      let(:id) { existing.id.to_s }

      it "finds the user" do
        expect(subject.first_name).to eq("Harrison")
      end
    end

    context "when the id has a leading zero" do
      let(:id) { "0#{existing.id}" }

      it "reads it as base 10" do
        expect(subject.id).to eq(existing.id)
      end
    end

    context "when no user has the id" do
      let(:id) { 999 }

      it { is_expected.to be_nil }
    end

    context "when the changes include non-writable fields" do
      let(:changes) { { id: 99, first_name: "Harrison", admin: true } }

      it "patches only the writable fields", :aggregate_failures do
        expect(subject).to have_attributes(id: existing.id, first_name: "Harrison")
      end
    end

    context "when the changes are invalid" do
      let(:changes) { { date_of_birth: "10/12/1990" } }

      it "returns the user with errors" do
        expect(subject.errors[:date_of_birth]).to include("must be a date in YYYY-MM-DD format")
      end

      it "leaves the stored user unchanged" do
        subject
        expect(repository.all.first.date_of_birth).to eq(Date.new(1990, 12, 10))
      end
    end
  end
end
