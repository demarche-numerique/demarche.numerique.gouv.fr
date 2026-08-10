# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20251112backfillChampSiretExternalStateWithEtablissementButNoValueOrExternalIdTask do
    describe "#process" do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :siret }]) }
      let(:dossier1) { create(:dossier, procedure:) }
      let(:champ1) { dossier1.root_public_champs.first }
      let(:etablissement1) { create(:etablissement, siret: "12345678901234") }

      subject(:process) { described_class.process(champ1) }
      before do
        champ1.update(etablissement: etablissement1, external_state: 'fetched', external_id: nil, value: nil)
      end
      context 'when champs was filled with SiretController' do
        it 'works' do
          expect { subject }.to change { champ1.reload.external_id }.to(etablissement1.siret)
        end
      end
    end
  end
end
