# frozen_string_literal: true

describe Instructeurs::EditController, type: :controller do
  let_it_be(:instructeur) { instructeurs.default }
  let_it_be(:procedure) { procedures.individual.tap { it.update!(instructeurs_can_edit_dossiers: true) } }
  let_it_be(:nom_stable_id) { stable_id_for('Nom du projet') }
  let_it_be(:description_stable_id) { stable_id_for('Description du projet') }
  let(:dossier) { dossiers.en_construction }

  def stable_id_for(libelle)
    procedure.active_revision.types_de_champ_public.find { it.libelle == libelle }.stable_id
  end

  # the seeded dossier leaves its two mandatory champs empty: fill the description,
  # so that the nom alone decides whether the dossier is valid
  def buffer_nom(value)
    dossier.with_instructeur_buffer_stream do
      dossier.public_champ_for_update(description_stable_id.to_s, updated_by: instructeur.email).assign_attributes(value: 'Une description')
      dossier.public_champ_for_update(nom_stable_id.to_s, updated_by: instructeur.email).assign_attributes(value:)
    end
    dossier.save!
  end

  def main_nom
    dossier.reload.champ_data
      .find { it.stream == Dossier::MAIN_STREAM && it.stable_id == nom_stable_id }
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
      before { buffer_nom('Valeur corrigée par l’instructeur') }

      it 'merges them onto the dossier and goes back to it' do
        expect { subject }.to change { dossier.traitements.count }.by(1)

        expect(response).to redirect_to(instructeur_dossier_path(procedure, dossier, statut: 'a-suivre'))
        expect(main_nom).to eq('Valeur corrigée par l’instructeur')
      end
    end

    # The confirmation dialog only opens on a valid dossier: this is the dossier
    # turned invalid in between, by a change made from another tab.
    context 'when the buffered changes make the dossier invalid' do
      let!(:nom_before) { main_nom }

      before { buffer_nom('') }

      it 'renders the form again with its errors and merges nothing' do
        expect { subject }.not_to change { dossier.traitements.count }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:show)
        expect(response.body).to include('Votre dossier contient 1 champ en erreur')
        expect(main_nom).to eq(nom_before)
      end
    end
  end
end
