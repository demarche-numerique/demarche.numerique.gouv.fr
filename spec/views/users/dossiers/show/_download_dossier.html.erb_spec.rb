# frozen_string_literal: true

describe 'users/dossiers/show/_download_dossier', type: :view do
  subject { render 'users/dossiers/show/download_dossier', dossier: }

  context 'with a dossier' do
    let(:dossier) { dossiers.en_construction }

    it { expect(subject).to have_link('Télécharger mon dossier (PDF)', href: dossier_path(dossier, format: :pdf)) }
  end

  context 'without dossier (admin preview of the end-of-submission message)' do
    let(:dossier) { nil }

    it 'shows the button without any download link' do
      expect(subject).to have_css('span.fr-btn', text: 'Télécharger mon dossier (PDF)')
      expect(subject).not_to have_link
    end
  end
end
