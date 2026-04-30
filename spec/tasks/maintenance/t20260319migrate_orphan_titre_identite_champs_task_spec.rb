# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260319migrateOrphanTitreIdentiteChampsTask do
    describe "#process" do
      subject(:process) { described_class.process }

      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let!(:titre_identite_champ) do
        dossier.champs.first.tap { it.update_column(:type, "Champs::TitreIdentiteChamp") }
      end
      let!(:piece_justificative_champ) do
        other_dossier = create(:dossier, :with_populated_champs, procedure:)
        other_dossier.champs.first
      end

      it "migrates orphan TitreIdentiteChamp to PieceJustificativeChamp" do
        process

        expect(titre_identite_champ.reload.type).to eq("Champs::PieceJustificativeChamp")
      end

      it "does not change existing PieceJustificativeChamp" do
        process

        expect(piece_justificative_champ.reload.type).to eq("Champs::PieceJustificativeChamp")
      end
    end
  end
end
