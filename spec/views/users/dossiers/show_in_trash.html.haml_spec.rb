# frozen_string_literal: true

describe 'users/dossiers/show_in_trash', type: :view do
  context 'draft put in trash manually' do
    let(:dossier) { create(:dossier, :brouillon, hidden_by_user_at: 1.hour.ago, hidden_by_reason: 'user_request') }

    before do
      assign(:hidden_dossier, dossier)
      render
    end

    it 'displays the title and trash link' do
      expect(rendered).to have_text("Le dossier n° #{dossier.id} a été mis à la corbeille")
      expect(rendered).to have_text('Consulter la corbeille')
      expect(rendered).not_to have_text('Si ce dossier"')
    end

    it 'links to the trash page' do
      expect(rendered).to have_link('Consulter la corbeille', href: trash_path)
    end

    it 'displays the restore option' do
      expect(rendered).to have_text('restaurer')
      expect(rendered).not_to have_text('télécharger')
    end
  end

  context 'non-brouillon ou corbeille non manuelle' do
    let(:dossier) { create(:dossier, hidden_by_user_at: 1.hour.ago, hidden_by_reason: 'expired') }

    before do
      assign(:hidden_dossier, dossier)
      render
    end

    it 'displays the title and trash link' do
      expect(rendered).to have_text("Le dossier n° #{dossier.id} a été mis à la corbeille")
      expect(rendered).to have_text('Consulter la corbeille')
    end

    it 'displays the restore and download options' do
      expect(rendered).to have_text('restaurer')
      expect(rendered).to have_text('télécharger')
    end
  end
end
