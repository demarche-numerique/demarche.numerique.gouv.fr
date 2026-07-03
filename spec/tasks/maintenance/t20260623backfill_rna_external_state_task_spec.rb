# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260623backfillRNAExternalStateTask do
    describe "#process" do
      subject(:process) { described_class.process(champ.champ_data) }

      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :rna }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:champ) { dossier.project_champs_public.first }

      context "quand le champ est idle avec une data déjà présente" do
        before do
          champ.update_columns(external_state: nil, external_id: 'W173847273', data: { 'association_titre' => 'Asso' })
        end

        it "le passe en fetched sans relancer de fetch" do
          expect { process }.to change { champ.reload.external_state }.from('idle').to('fetched')
        end
      end

      context "quand le champ est idle avec un external_id valide mais sans data" do
        before do
          champ.update_columns(external_state: nil, external_id: 'W173847273', data: nil)
        end

        it "relance le workflow async" do
          expect { process }.to change { champ.reload.external_state }.from('idle').to('waiting_for_job')
            .and have_enqueued_job(ChampFetchExternalDataJob).with(champ.champ_data, "W173847273")
        end
      end

      context "quand le champ est idle avec un external_id invalide et sans data" do
        before do
          champ.update_columns(external_state: nil, external_id: 'not-a-rna', data: nil)
        end

        it "ne fait rien" do
          expect { process }.not_to change { champ.reload.external_state }.from('idle')
        end
      end
    end
  end
end
