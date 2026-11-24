# frozen_string_literal: true

describe 'users/dossiers/show/_download_attestation', type: :view do
  subject { render 'users/dossiers/show/download_attestation', dossier: }

  context 'with an attestation' do
    let(:dossier) { create(:dossier, :accepte, attestation: create(:attestation, :with_pdf)) }

    it { expect(subject).to have_link('Télécharger mon attestation (PDF)', href: attestation_dossier_path(dossier)) }
  end

  context 'without attestation' do
    let(:dossier) { dossiers.accepte }

    it { expect(subject).to be_blank }
  end
end
