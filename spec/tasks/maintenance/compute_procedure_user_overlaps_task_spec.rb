# frozen_string_literal: true

require 'rails_helper'

module Maintenance
  RSpec.describe ComputeProcedureUserOverlapsTask do
    empty_seeds ProcedureUserOverlap

    let(:left) { create(:procedure, :published, public_type_de_champs: [{ type: :text }]) }
    let(:right) { create(:procedure, :published, public_type_de_champs: [{ type: :text }]) }
    let(:outside) { create(:procedure, :published, public_type_de_champs: [{ type: :text }]) }

    def enable(*procedures)
      procedures.each { Flipper.enable(:champ_matching, ProcedureFlipperActor.new(it.id)) }
    end

    describe '#process' do
      before do
        stub_const('ChampMatchingConcern::USERS_FLOOR', 1)

        user = create(:user)
        [left, right, outside].each { create(:dossier, :en_construction, procedure: it, user:) }
      end

      it 'pairs the flagged procedures and leaves the others alone' do
        enable(left, right)

        described_class.new.process

        expect(ProcedureUserOverlap.pluck(:left_procedure_id, :right_procedure_id))
          .to contain_exactly([left.id, right.id].minmax)
      end

      it 'writes nothing when the flag names a single procedure' do
        enable(left)

        described_class.new.process

        expect(ProcedureUserOverlap.count).to eq(0)
      end
    end
  end
end
