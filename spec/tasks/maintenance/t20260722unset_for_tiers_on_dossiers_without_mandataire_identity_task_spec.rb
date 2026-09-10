# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260722unsetForTiersOnDossiersWithoutMandataireIdentityTask do
    let(:procedure) { create(:procedure, :for_individual) }

    describe "#collection" do
      subject(:collection) { described_class.new.collection }

      let!(:poisoned) do
        create(:dossier, :en_construction, :with_individual, procedure:)
          .tap { it.update_columns(for_tiers: true, mandataire_first_name: nil, mandataire_last_name: nil) }
      end
      let!(:valid_for_tiers) do
        create(:dossier, :en_construction, :with_individual, procedure:)
          .tap { it.update_columns(for_tiers: true, mandataire_first_name: 'Jeanne', mandataire_last_name: 'Dupont') }
      end
      let!(:brouillon) do
        create(:dossier, :with_individual, procedure:)
          .tap { it.update_columns(for_tiers: true, mandataire_first_name: nil, mandataire_last_name: nil) }
      end

      it "targets only deposited for_tiers dossiers missing the mandataire identity" do
        expect(collection).to include(poisoned)
        expect(collection).not_to include(valid_for_tiers)
        expect(collection).not_to include(brouillon)
      end

      it "leaves out a dossier whose mandataire identity is filled once the ids are collected" do
        relation = described_class.new.collection
        poisoned.update_columns(mandataire_first_name: 'Jeanne', mandataire_last_name: 'Dupont')

        expect(relation).not_to include(poisoned)
      end
    end

    describe "#process" do
      subject(:process) { described_class.process(dossier) }

      let(:dossier) do
        create(:dossier, :en_construction, :with_individual, procedure:)
          .tap { it.update_columns(for_tiers: true, mandataire_first_name: nil, mandataire_last_name: '') }
      end

      it "unsets for_tiers and makes the dossier valid again" do
        expect { process }.to change { dossier.reload.for_tiers }.from(true).to(false)
        expect(dossier.mandataire_last_name).to be_nil
        expect(dossier).to be_valid
      end
    end
  end
end
