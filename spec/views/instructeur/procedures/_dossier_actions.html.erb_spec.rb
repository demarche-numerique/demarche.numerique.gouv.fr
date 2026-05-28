# frozen_string_literal: true

describe 'instructeurs/procedures/_dossier_actions', type: :view do
  let(:procedure) { create(:procedure, :published) }

  subject do
    render('instructeurs/procedures/dossier_actions',
            procedure_id: procedure.id,
            dossier_id: dossier.id,
            dossier: dossier,
            state: dossier.state,
            archived: false,
            dossier_is_followed: false,
            close_to_expiration: true,
            hidden_by_administration: false,
            hidden_by_expired: false,
            has_pending_correction: false,
            has_blocking_pending_correction: false,
            turbo: false,
            with_menu: false)
  end

  context 'when the dossier is en_construction and close to expiration' do
    let(:dossier) { create(:dossier, :en_construction, procedure:) }

    it 'does not offer to repasser en instruction (invalid transition from en_construction)' do
      expect(subject).not_to have_button('Repasser en instruction')
    end

    it 'offers the normal en_construction action' do
      expect(subject).to have_button('Passer en instruction')
    end
  end

  context 'when the dossier is termine and close to expiration' do
    let(:dossier) { create(:dossier, :accepte, procedure:) }

    it 'still offers to repasser en instruction' do
      expect(subject).to have_button('Repasser en instruction')
    end
  end
end
