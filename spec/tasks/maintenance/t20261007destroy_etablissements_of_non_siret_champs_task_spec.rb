# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20261007destroyEtablissementsOfNonSiretChampsTask do
    describe "#process" do
      subject(:process) { described_class.new.process(Etablissement.where(id: etablissement.id)) }

      let(:etablissement) { create(:etablissement) }

      context "when a non-siret champ carries an etablissement" do
        let(:dossier) { dossiers.entreprise_en_instruction }
        let(:champ) { dossier.champ_data.find { it.type == 'Champs::TextChamp' } }

        before { champ.update_columns(etablissement_id: etablissement.id) }

        it "unlinks the champ and destroys the etablissement" do
          process

          expect(champ.reload.etablissement_id).to be_nil
          expect(Etablissement.exists?(etablissement.id)).to be(false)
        end

        it "does not make the dossier look freshly modified" do
          expect { process }.not_to change { dossier.reload.updated_at }
        end
      end

      context "when a siret champ carries the etablissement" do
        let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :siret }]) }
        let(:champ) { create(:dossier, procedure:).root_champs_public.first }

        before { champ.update_columns(etablissement_id: etablissement.id) }

        it "leaves it alone" do
          process

          expect(champ.reload.etablissement_id).to eq(etablissement.id)
        end
      end
    end
  end
end
