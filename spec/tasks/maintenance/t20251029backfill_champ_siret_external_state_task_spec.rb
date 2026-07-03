# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20251029backfillChampSiretExternalStateTask do
    describe "#process" do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :siret }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:champ) { dossier.project_champs_public.first }

      subject(:process) { described_class.process(ChampData.where(type: "Champs::SiretChamp")) }

      context 'when champs was filled with SiretController' do
        it 'works' do
          champ.update(etablissement: create(:etablissement), external_state: 'idle', external_id: nil, value: "12345678901234")
          expect { subject }.to change { champ.reload.external_state }.from('idle').to('fetched')
          expect(champ.external_id).to eq(champ.value)
        end
      end
    end
  end
end
