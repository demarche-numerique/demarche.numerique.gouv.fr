# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe FixChampsCommuneHavingValueButNotExternalIdTask do
    describe "#process" do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :communes }]) }
      let(:dossier) { create(:dossier, state, :with_populated_champs, procedure:) }
      let(:champ) { dossier.project_champs_public.first }
      subject(:process) do
        described_class.process(champ.champ_data)
      end

      context 'when search find one result', vcr: { cassette_name: 'fix-champs-commune-with-one-results' } do
        let(:state) { [:en_instruction, :en_construction].sample }
        let!(:expected_external_id) { champ.external_id }
        before { champ.update_column(:external_id, nil) }

        it "backfill external_id", :slow do
          expect { subject }.to change { champ.reload.external_id }.from(nil).to(expected_external_id)
        end
      end

      context 'when search find 0 or more than 1 results', vcr: { cassette_name: 'fix-champs-commune-with-more-than-one-results' } do
        let(:instructeur) { create(:instructeur, user: create(:user, email: Maintenance::FixChampsCommuneHavingValueButNotExternalIdTask::DEFAULT_INSTRUCTEUR_EMAIL)) }
        before do
          instructeur
          champ.update_columns(external_id: nil, value: 'Marseille') # more than one marseille in france
        end

        context 'en_instruction (go back to en_construction!), send comment' do
          let(:state) { :en_construction }

          it 'flags as pending correction' do
            expect { subject }.to change { champ.reload.value }.from('Marseille').to(nil)
            expect(Commentaire.first.instructeur).to eq(instructeur)
            expect(champ.dossier.state).to eq("en_construction")
          end
        end

        context 'when champs will passthru validator (ie: state is brouillon)' \
                'or champ belongs to dossier.termine (ie: state is accepte, refuse or classer_sans_suite)' do
          let(:state) { [:brouillon, :accepte, :refuse, :sans_suite].sample }

          it "skips backfill as well as asks for correction" do
            expect { subject }.not_to change { champ.reload }
          end
        end
      end
    end
  end
end
