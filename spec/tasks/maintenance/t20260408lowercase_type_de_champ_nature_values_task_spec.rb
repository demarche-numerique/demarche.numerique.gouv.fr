# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260408lowercaseTypeDeChampNatureValuesTask do
    describe "#process" do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative }]) }
      let(:type_de_champ) { procedure.draft_revision.types_de_champ.first }

      before do
        TypeDeChamp.where(id: type_de_champ.id).update_all(nature: 'TITRE_IDENTITE')
        type_de_champ.reload
      end

      it "lowercases the nature value" do
        described_class.process(TypeDeChamp.where(id: type_de_champ.id))
        expect(type_de_champ.reload.read_attribute_before_type_cast(:nature)).to eq('titre_identite')
      end
    end

    describe "#collection" do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative, nature: 'titre_identite' }, { type: :piece_justificative }]) }

      before do
        tdc = procedure.draft_revision.types_de_champ.find(&:titre_identite?)
        TypeDeChamp.where(id: tdc.id).update_all(nature: 'TITRE_IDENTITE')
      end

      it "returns only types_de_champ with non-null nature" do
        expect(described_class.new.collection.count).to eq(1)
      end
    end
  end
end
