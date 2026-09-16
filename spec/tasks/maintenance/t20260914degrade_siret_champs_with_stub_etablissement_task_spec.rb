# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260914degradeSiretChampsWithStubEtablissementTask do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :siret }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.root_champs_public.first }
    let(:siret) { '30613890001294' }

    describe "#collection" do
      subject(:collection) { described_class.new.collection }

      before { champ.update_columns(external_id: siret, value: siret, etablissement_id: etablissement.id, external_state:) }

      context "when a fetched champ carries a stub" do
        let(:etablissement) { create(:etablissement, adresse: nil, siret:) }
        let(:external_state) { 'fetched' }

        it { is_expected.to include(etablissement) }
      end

      context "when a champ in external_error carries a stub" do
        let(:etablissement) { create(:etablissement, adresse: nil, siret:) }
        let(:external_state) { 'external_error' }

        it { is_expected.to include(etablissement) }
      end

      context "when the etablissement is complete" do
        let(:etablissement) { create(:etablissement, siret:) }
        let(:external_state) { 'external_error' }

        it "leaves the champ alone: this is a real error, not an outage" do
          expect(collection).not_to include(etablissement)
        end
      end

      context "when the champ is already degraded" do
        let(:etablissement) { create(:etablissement, adresse: nil, siret:) }
        let(:external_state) { 'degraded' }

        it { is_expected.not_to include(etablissement) }
      end
    end

    describe "#process" do
      subject(:process) { described_class.process(etablissement) }

      let(:etablissement) { create(:etablissement, adresse: nil, siret:) }
      let(:external_state) { 'fetched' }

      before { champ.update_columns(external_id: siret, value: siret, etablissement_id: etablissement.id, external_state:) }

      it "moves the champ to degraded so the cron picks it up" do
        expect { process }.to change { champ.reload.external_state }.from('fetched').to('degraded')
      end

      it "drops the stub and keeps the siret readable" do
        process

        expect(champ.reload.etablissement).to be_nil
        expect(champ.reload.value).to eq(siret)
        expect(Etablissement.find_by(id: etablissement.id)).to be_nil
      end

      it "does not make the dossier look freshly modified to its instructeur" do
        expect { process }.not_to change { dossier.reload.updated_at }
      end

      # A legacy champ has no value_updated_at and falls back on updated_at: the
      # "Modifié le" badge would date every migrated champ at the deploy.
      it "does not make the champ look modified either" do
        expect { process }.not_to change { champ.reload.updated_at }
      end

      context "when the champ is from before value_updated_at existed" do
        let(:filled_at) { 2.years.ago.change(usec: 0) }

        before { champ.update_columns(value_updated_at: nil, updated_at: filled_at) }

        it "freezes the date it shows, so the cron replays cannot move it" do
          process

          expect(champ.reload[:value_updated_at]).to eq(filled_at)
        end
      end

      context "when the champ already has its value_updated_at" do
        let(:edited_at) { 1.month.ago.change(usec: 0) }

        before { champ.update_columns(value_updated_at: edited_at) }

        it "keeps it" do
          process

          expect(champ.reload[:value_updated_at]).to eq(edited_at)
        end
      end

      context "when the champ is in external_error" do
        let(:external_state) { 'external_error' }

        it "moves it to degraded as well" do
          expect { process }.to change { champ.reload.external_state }.from('external_error').to('degraded')
        end
      end

      context "when the champ never got its external_id backfilled" do
        before { champ.update_columns(external_id: nil, value: nil) }

        it "takes the siret back from the stub instead of losing it" do
          process

          expect(champ.reload).to be_degraded
          expect(champ.siret).to eq(siret)
        end
      end
    end
  end
end
