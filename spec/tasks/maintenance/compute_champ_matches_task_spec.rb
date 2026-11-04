# frozen_string_literal: true

require 'rails_helper'

module Maintenance
  RSpec.describe ComputeChampMatchesTask do
    empty_seeds ProcedureUserOverlap

    let(:left) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Votre adresse' }]) }
    let(:right) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Adresse du domicile' }]) }

    let(:overlap) do
      ProcedureUserOverlap.create!(left_procedure_id: [left.id, right.id].min, right_procedure_id: [left.id, right.id].max,
                                   common_users_count: 1)
    end

    before do
      user = create(:user)
      [left, right].each do |procedure|
        dossier = create(:dossier, :en_construction, procedure:, user:)
        dossier.champ_data.find { !it.private? }.update_column(:value, '12 rue du Pont')
      end
    end

    describe '#collection' do
      it 'queues the pairs whose champs have never been compared' do
        computed = overlap
        computed.update!(champs_computed_at: Time.current)

        expect(described_class.new.collection).to be_empty

        computed.update!(champs_computed_at: nil)
        expect(described_class.new.collection).to contain_exactly(computed)
      end
    end

    describe '#process' do
      it 'writes the champ couples of the pair and marks it computed' do
        stub_const('ChampMatchingConcern::USERS_FLOOR', 1)

        expect { described_class.new.process(overlap) }
          .to change(TypeDeChampMatch, :count).from(0).to(1)

        expect(overlap.reload.champs_computed_at).to be_present
        expect(TypeDeChampMatch.first).to have_attributes(matching_users_count: 1, common_users_count: 1)
      end

      it 'marks the pair computed even when no couple clears the floor' do
        stub_const('ChampMatchingConcern::USERS_FLOOR', 2)

        described_class.new.process(overlap)

        expect(TypeDeChampMatch.count).to eq(0)
        expect(overlap.reload.champs_computed_at).to be_present
      end
    end
  end
end
