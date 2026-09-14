# frozen_string_literal: true

RSpec.describe Cron::BackfillSiretDegradedModeJob, type: :job do
  describe '.perform' do
    let(:etablissement) { create(:etablissement, adresse: nil, siret: '01234567891011') }
    let(:new_adresse) { '7 rue du puits, coye la foret' }

    context 'fix etablissement with dossier with adresse nil' do
      let(:dossier) { create(:dossier, :en_construction, etablissement: etablissement) }
      before do
        dossier
      end
      it 'works' do
        allow_any_instance_of(APIEntreprise::EtablissementAdapter).to receive(:to_params).and_return(Dry::Monads::Success({ adresse: new_adresse }))
        expect { Cron::BackfillSiretDegradedModeJob.perform_now }.to change { etablissement.reload.adresse }.from(nil).to(new_adresse)
      end
    end

    context 'fix etablisEtablissementAdapter.newsement with champs with adresse nil' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
      let(:public_type_de_champs) { [{ type: :siret }] }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:champ_siret) { dossier.champ_data.first }

      before do
        champ_siret
        champ_siret.update_columns(etablissement_id: etablissement.id, external_state: 'degraded')
      end
      it 'works' do
        allow_any_instance_of(APIEntreprise::EtablissementAdapter).to receive(:to_params).and_return(Dry::Monads::Success({ adresse: new_adresse }))
        expect { Cron::BackfillSiretDegradedModeJob.perform_now }.to change { etablissement.reload.adresse }.from(nil).to(new_adresse)
      end

      it 'gets the champ out of the degraded state' do
        allow_any_instance_of(APIEntreprise::EtablissementAdapter).to receive(:to_params).and_return(Dry::Monads::Success({ adresse: new_adresse }))
        expect { Cron::BackfillSiretDegradedModeJob.perform_now }.to change { champ_siret.reload.external_state }.from('degraded').to('fetched')
      end
    end
  end
end
