# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe DeleteDraftRevisionTypeDeChampsTask do
    let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
    let(:public_type_de_champs) {
      [
        { type: :text, libelle: "Text", stable_id: 11, mandatory: true },
        { type: :integer_number, libelle: "Number", description: "Old desc", stable_id: 12 },
        {
          type: :repetition, libelle: "Bloc", stable_id: 13, children: [
            { type: :text, libelle: "RepText", stable_id: 131, description: "Remove me", mandatory: true },
            { type: :integer_number, libelle: "RepNum", stable_id: 132 },
          ],
        },
      ]
    }

    let(:csv) do
      <<~CSV
        demarche_id,id,new_libelle,new_description,new_required,new_position,delete_flag
        #{procedure.id},#{find_by_stable_id(12).to_typed_id},[NEW] Number,[NEW] Number desc,true,0,
        #{procedure.id},#{find_by_stable_id(13).to_typed_id},Bloc,[NEW] bloc desc,,1,
        #{procedure.id},#{find_by_stable_id(132).to_typed_id},[NEW] RepNum,,true,2,true
        #{procedure.id},#{find_by_stable_id(131).to_typed_id},[NEW] RepText,,,3,
        #{procedure.id},#{find_by_stable_id(11).to_typed_id},[supp] Text,,,4,true
      CSV
    end

    let(:rows) do
      CSV.parse(csv, headers: true, skip_blanks: true).map(&:to_h)
    end

    describe "#process" do
      subject(:process) do
        rows.each { described_class.process(_1) }
        procedure.reload
      end

      it "delete the flagged rows" do
        process

        tdc = find_by_stable_id(12)
        expect(tdc).not_to be_nil

        tdc = find_by_stable_id(13)
        expect(tdc).not_to be_nil

        tdc = find_by_stable_id(11)
        expect(tdc).to be_nil

        tdc, coord = find_with_coordinate_by_stable_id(131)
        expect(tdc).not_to be_nil
        expect(coord.position).to eq(0) # reindexed

        tdc = find_by_stable_id(132)
        expect(tdc).to be_nil
      end
    end

    def find_by_stable_id(stable_id)
      procedure.draft_revision.type_de_champs.find { _1.stable_id == stable_id }
    end

    def find_with_coordinate_by_stable_id(stable_id)
      tdc = find_by_stable_id(stable_id)
      [tdc, procedure.draft_revision.coordinate_for(tdc)]
    end
  end
end
