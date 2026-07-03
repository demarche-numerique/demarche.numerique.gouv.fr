# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20251023MigrateChampsPaysAfterAPIGeoUpdateTask do
    describe "#collection" do
      subject(:collection) { described_class.collection }

      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :pays }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:champ_pays) { dossier.project_champs_public.first }

      context 'when champ has a country that needs migration' do
        before { champ_pays.update_columns(value: "Guadeloupe", external_id: "GP") }

        it { expect(collection).to include(champ_pays.champ_data) }
      end
    end

    describe "#process" do
      subject(:process) { described_class.new.process(champ_pays) }

      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :pays }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:champ_pays) { dossier.project_champs_public.first }

      context 'when migrating DOM to France' do
        before { champ_pays.update_columns(value: "Martinique", external_id: "MQ") }

        it 'updates value and external_id to France' do
          expect { subject }.to change { champ_pays.reload.value }.from("Martinique").to("France")
            .and change { champ_pays.reload.external_id }.from("MQ").to("FR")
        end
      end

      context 'when updating country label' do
        before { champ_pays.update_columns(value: "îles Cook", external_id: "CK") }

        it 'updates value while keeping the correct code' do
          expect { subject }.to change { champ_pays.reload.value }.from("îles Cook").to("Îles Cook")
          expect(champ_pays.reload.external_id).to eq("CK")
        end
      end

      context 'when value is not in the mapping' do
        before { champ_pays.update_columns(value: "Allemagne", external_id: "DE") }

        it 'does not update the champ' do
          expect { subject }.not_to change { champ_pays.reload.champ_data.attributes }
        end
      end
    end
  end
end
