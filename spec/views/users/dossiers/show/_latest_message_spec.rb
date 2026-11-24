# frozen_string_literal: true

describe 'users/dossiers/show/_latest_message', type: :view do
  before { sign_in dossier.user }

  subject { render 'users/dossiers/show/latest_message', dossier: }

  context 'with messages' do
    let(:dossier) { dossiers.en_construction }

    it 'shows the latest message and a link to answer it' do
      expect(subject).to have_css('h2', text: 'Dernier message')
      expect(subject).to have_text('le projet commencera au début du mois de septembre')
      expect(subject).to have_link(href: messagerie_dossier_url(dossier, anchor: 'new_commentaire'))
    end
  end

  context 'without messages' do
    let(:dossier) { dossiers.brouillon }

    it { expect(subject).to be_blank }
  end
end
