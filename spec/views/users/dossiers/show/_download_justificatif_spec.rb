# frozen_string_literal: true

describe 'users/dossiers/show/_download_justificatif', type: :view do
  subject { render 'users/dossiers/show/download_justificatif', dossier: }

  context 'with a justificatif' do
    let(:dossier) { create(:dossier, :accepte, :with_justificatif) }

    it 'shows the justificatif download link' do
      expect(subject).to have_text('Justificatif de décision')
      expect(subject).to have_link(text: 'hello.txt')
    end
  end

  context 'without justificatif' do
    let(:dossier) { dossiers.accepte }

    it { expect(subject).to be_blank }
  end
end
