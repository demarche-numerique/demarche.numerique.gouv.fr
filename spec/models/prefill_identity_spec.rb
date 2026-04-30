# frozen_string_literal: true

RSpec.describe PrefillIdentity do
  describe "#to_h" do
    let(:dossier) { create(:dossier, :brouillon, :with_individual) }

    subject(:prefill_identity_hash) { described_class.new(dossier, params).to_h }

    context "if genre is correct" do
      let(:params) {
        {
          "identite_prenom" => "Prénom",
          "identite_nom" => "Nom",
        }
      }

      it "builds an array of hash(id, value) matching all the given params" do
        expect(prefill_identity_hash).to match({ prenom: "Prénom", nom: "Nom", gender: nil })
      end
    end

    context "when identite_genre is a hash (malicious input)" do
      let(:params) {
        {
          "identite_prenom" => "Prénom",
          "identite_nom" => "Nom",
          "identite_genre" => { "injected" => "x" },
        }
      }

      it "rejects the non-string genre" do
        expect(prefill_identity_hash[:gender]).to be_nil
      end
    end

    context "when identite_genre is a valid constant value" do
      let(:procedure) { create(:procedure, :for_individual, no_gender: false) }
      let(:dossier) { create(:dossier, :brouillon, :with_individual, procedure:) }
      let(:params) {
        {
          "identite_prenom" => "Prénom",
          "identite_nom" => "Nom",
          "identite_genre" => Individual::GENDER_FEMALE,
        }
      }

      it "keeps the valid gender" do
        expect(prefill_identity_hash[:gender]).to eq(Individual::GENDER_FEMALE)
      end
    end
  end
end
