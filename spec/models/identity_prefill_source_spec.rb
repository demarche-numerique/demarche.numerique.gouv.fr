# frozen_string_literal: true

RSpec.describe IdentityPrefillSource do
  let(:procedure) { create(:procedure, :for_individual, no_gender: false) }
  let(:dossier) { create(:dossier, :with_individual, procedure:, user:) }
  let(:pro_connect) { false }

  subject(:source) { described_class.new(dossier:, pro_connect:) }

  context "when the user has no identity provider" do
    let(:user) { create(:user) }

    it "resolves to no source and locks nothing" do
      expect(source.name).to be_nil
      expect(source).to be_none
      expect(source.individual_locked_fields).to eq([])
      expect(source.mandataire_locked?).to be(false)
    end
  end

  context "when the user is FranceConnected" do
    let(:user) { create(:user, :with_fci) }

    it "resolves to :france_connect and locks nom/prenom/gender" do
      expect(source.name).to eq(:france_connect)
      expect(source.individual_locked_fields).to contain_exactly(:nom, :prenom, :gender)
    end

    context "with an incomplete identity" do
      let(:user) { create(:user, france_connect_informations: [build(:france_connect_information, family_name: nil)]) }

      it { expect(source.name).to be_nil }
    end
  end

  context "when the session is ProConnected" do
    let(:user) { create(:user, :with_pci) }
    let(:pro_connect) { true }

    it "resolves to :pro_connect and locks nom/prenom but not gender" do
      expect(source.name).to eq(:pro_connect)
      expect(source.individual_locked_fields).to contain_exactly(:nom, :prenom)
    end

    context "when ProConnect did not provide a usual name" do
      let(:user) { create(:user, pro_connect_informations: [build(:pro_connect_information, usual_name: nil)]) }

      it { expect(source.name).to be_nil }
    end

    context "but the session flag is false" do
      let(:pro_connect) { false }

      it { expect(source.name).to be_nil }
    end
  end

  context "when the user has both identities" do
    let(:user) { create(:user, :with_fci, :with_pci) }

    context "and the session is ProConnected" do
      let(:pro_connect) { true }

      it "the current session wins" do
        expect(source.name).to eq(:pro_connect)
        expect(source.individual_locked_fields).to contain_exactly(:nom, :prenom)
      end
    end

    context "and the session is not ProConnected" do
      let(:pro_connect) { false }

      it "falls back to FranceConnect" do
        expect(source.name).to eq(:france_connect)
        expect(source.individual_locked_fields).to contain_exactly(:nom, :prenom, :gender)
      end
    end

    context "with the ProConnect session but an incomplete ProConnect identity" do
      let(:user) { create(:user, :with_fci, pro_connect_informations: [build(:pro_connect_information, usual_name: nil)]) }
      let(:pro_connect) { true }

      it "falls back to FranceConnect" do
        expect(source.name).to eq(:france_connect)
      end
    end
  end

  context "when the dossier is for_tiers" do
    let(:dossier) { create(:dossier, :for_tiers_without_notification, procedure:, user:) }

    context "FranceConnected" do
      let(:user) { create(:user, :with_fci) }

      it "locks the mandataire and nothing on the individual" do
        expect(source.mandataire_locked?).to be(true)
        expect(source.individual_locked_fields).to eq([])
      end
    end

    context "ProConnected" do
      let(:user) { create(:user, :with_pci) }
      let(:pro_connect) { true }

      it "locks the mandataire and nothing on the individual" do
        expect(source.mandataire_locked?).to be(true)
        expect(source.individual_locked_fields).to eq([])
      end
    end

    context "without an identity provider" do
      let(:user) { create(:user) }

      it { expect(source.mandataire_locked?).to be(false) }
    end
  end
end
