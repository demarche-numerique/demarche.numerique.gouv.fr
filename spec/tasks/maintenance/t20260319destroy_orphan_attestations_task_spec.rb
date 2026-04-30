# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260319destroyOrphanAttestationsTask do
    describe "#collection" do
      subject(:collection) { described_class.collection }

      let!(:dossier_sans_suite) { create(:dossier, :sans_suite) }
      let!(:orphan_attestation) { create(:attestation, dossier: dossier_sans_suite) }

      let!(:dossier_accepte) { create(:dossier, :accepte) }
      let!(:valid_accepte_attestation) { create(:attestation, dossier: dossier_accepte) }

      let!(:dossier_refuse) { create(:dossier, :refuse) }
      let!(:valid_refuse_attestation) { create(:attestation, dossier: dossier_refuse) }

      it "returns only attestations on sans_suite dossiers" do
        expect(collection).to include(orphan_attestation)
        expect(collection).not_to include(valid_accepte_attestation)
        expect(collection).not_to include(valid_refuse_attestation)
      end
    end

    describe "#process" do
      let!(:dossier_sans_suite) { create(:dossier, :sans_suite) }
      let!(:orphan_attestation) { create(:attestation, dossier: dossier_sans_suite) }

      it "destroys the attestation" do
        expect { described_class.process(orphan_attestation) }
          .to change { Attestation.count }.by(-1)

        expect(dossier_sans_suite.reload.attestation).to be_nil
      end
    end
  end
end
