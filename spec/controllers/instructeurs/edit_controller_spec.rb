# frozen_string_literal: true

describe Instructeurs::EditController, type: :controller do
  let(:instructeur) { create(:instructeur) }
  let(:procedure) do
    create(:procedure, :published,
      instructeurs: [instructeur],
      instructeurs_can_edit_dossiers: true,
      public_type_de_champs: [{ type: :text, libelle: 'Texte', stable_id: 99, mandatory: true }])
  end
  let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }

  def buffer_value(value)
    dossier.with_instructeur_buffer_stream do
      dossier.public_champ_for_update('99', updated_by: instructeur.email).assign_attributes(value:)
    end
    dossier.save!
  end

  def main_value
    dossier.reload.champ_data
      .find { it.stream == Dossier::MAIN_STREAM && it.stable_id == 99 }
      &.value
  end

  before { sign_in(instructeur.user) }

  describe '#submit' do
    render_views

    subject do
      patch :submit, params: {
        procedure_id: procedure.id,
        dossier_id: dossier.id,
        statut: 'a-suivre',
        traitement: { motivation: 'J’ai corrigé une coquille.' },
      }
    end

    context 'when the buffered changes are valid' do
      before { buffer_value('Valeur corrigée par l’instructeur') }

      it 'merges them onto the dossier and goes back to it' do
        expect { subject }.to change { dossier.traitements.count }.by(1)

        expect(response).to redirect_to(instructeur_dossier_path(procedure, dossier, statut: 'a-suivre'))
        expect(main_value).to eq('Valeur corrigée par l’instructeur')
      end
    end

    # The confirmation dialog only opens on a valid dossier: this is the dossier
    # turned invalid in between, by a change made from another tab.
    context 'when the buffered changes make the dossier invalid' do
      let!(:value_before) { main_value }

      before { buffer_value('') }

      it 'renders the form again with its errors and merges nothing' do
        expect { subject }.not_to change { dossier.traitements.count }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:show)
        expect(response.body).to include('Votre dossier contient 1 champ en erreur')
        expect(main_value).to eq(value_before)
      end
    end
  end
end
