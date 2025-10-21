# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe BackfillIdentityKindOnProceduresTask do
    describe "#process" do
      subject(:process) { described_class.process(procedure) }

      let(:procedure) { create(:procedure) }

      before { procedure.update_columns(identity_kind: nil, for_individual:) }

      context 'when the procedure targets an individual' do
        let(:for_individual) { true }

        it 'backfills identity_kind with individual' do
          process
          expect(procedure.reload.identity_kind).to eq('individual')
        end
      end

      context 'when the procedure targets a personne morale' do
        let(:for_individual) { false }

        it 'backfills identity_kind with personne_morale' do
          process
          expect(procedure.reload.identity_kind).to eq('personne_morale')
        end
      end
    end

    describe "#collection" do
      it 'only includes procedures without an identity_kind' do
        without = create(:procedure).tap { _1.update_column(:identity_kind, nil) }
        with = create(:procedure, :for_individual)

        collection = described_class.new.collection
        expect(collection).to include(without)
        expect(collection).not_to include(with)
      end
    end
  end
end
