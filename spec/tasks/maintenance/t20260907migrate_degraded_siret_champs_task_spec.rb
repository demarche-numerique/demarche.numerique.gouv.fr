# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260907migrateDegradedSiretChampsTask do
    describe "#process" do
      subject(:process) { described_class.process(champ) }

      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :siret }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:champ) { dossier.root_champs_public.first }
      let(:siret) { '30613890001294' }

      before do
        champ.update_columns(external_id: siret, etablissement_id: etablissement.id, external_state: 'external_error')
      end

      context "when the champ carries a stub" do
        let(:etablissement) { create(:etablissement, adresse: nil, siret:) }

        it "moves it to degraded so the cron picks it up" do
          expect { process }.to change { champ.reload.external_state }.from('external_error').to('degraded')
        end

        it "drops the stub and keeps the siret readable" do
          process

          expect(champ.reload.etablissement).to be_nil
          expect(champ.reload.value).to eq(siret)
          expect(Etablissement.find_by(id: etablissement.id)).to be_nil
        end
      end

      context "when the champ never got its external_id backfilled" do
        let(:etablissement) { create(:etablissement, adresse: nil, siret:) }

        before { champ.update_columns(external_id: nil, value: nil) }

        it "takes the siret back from the stub instead of skipping the champ" do
          process

          expect(champ.reload).to be_degraded
          expect(champ.siret).to eq(siret)
        end
      end

      context "when the etablissement is complete" do
        let(:etablissement) { create(:etablissement, siret:) }

        it "leaves the champ alone: this is a real error, not an outage" do
          expect { process }.not_to change { champ.reload.external_state }
        end
      end
    end
  end
end
