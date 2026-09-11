# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260911BackfillMissingGeoAreaUuidTask do
    describe "#process" do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :carte }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:main_champ) { dossier.champ_data.first }
      let(:buffer_champ) do
        champ = main_champ.dup
        champ.stream = Dossier::USER_BUFFER_STREAM
        champ.save!(validate: false)
        champ
      end

      def create_geo_area_without_uuid(champ_data, *traits)
        create(:geo_area, :selection_utilisateur, *traits, champ_data:).tap do |geo_area|
          geo_area.update_column(:uuid, nil)
        end
      end

      let(:geo_area) { create_geo_area_without_uuid(main_champ, :polygon) }

      subject(:process) { described_class.new.process(geo_area) }

      it 'assigns a uuid to a geo_area that has none' do
        expect { process }.to change { geo_area.reload.uuid }.from(nil).to(a_kind_of(String))
      end

      it 'is idempotent' do
        process
        expect { described_class.new.process(geo_area) }.not_to change { geo_area.reload.uuid }
      end

      it 'is not restricted to the main stream' do
        buffer_geo_area = create_geo_area_without_uuid(buffer_champ, :polygon)

        expect { described_class.new.process(buffer_geo_area) }.to change { buffer_geo_area.reload.uuid }.from(nil).to(a_kind_of(String))
      end

      context 'when the same area exists in another stream' do
        let!(:buffer_geo_area) { create_geo_area_without_uuid(buffer_champ, :polygon) }

        it 'gives both copies the same uuid' do
          process
          expect(buffer_geo_area.reload.uuid).to eq(geo_area.reload.uuid)
        end

        it 'reuses the uuid a copy already carries' do
          buffer_geo_area.update_column(:uuid, 'already-there')
          process
          expect(geo_area.reload.uuid).to eq('already-there')
        end
      end

      context 'when another stream holds a different area' do
        let!(:buffer_geo_area) { create_geo_area_without_uuid(buffer_champ, :point) }

        it 'leaves it alone' do
          process
          expect(buffer_geo_area.reload.uuid).to be_nil
        end
      end
    end
  end
end
