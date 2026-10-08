# frozen_string_literal: true

require "rails_helper"

RSpec.describe 'shared/dossiers/_messagerie', type: :view do
  # a brouillon is not visible by the administration: its messaging is disabled
  let(:dossier) { dossiers.brouillon }
  let(:modal_html) { rendered }

  before do
    render partial: 'shared/dossiers/messagerie', locals: {
      dossier:,
      connected_user: users.usager,
      messagerie_seen_at: nil,
      new_commentaire: Commentaire.new,
      form_url: '/',
    }
  end

  it_behaves_like 'a labelled DSFR modal', 'messagerie-close-explanations'

  it 'tells the usager which dossier to mention' do
    expect(rendered).to have_css('#messagerie-close-explanations-title', text: 'La messagerie est désactivée.', visible: :all)
    expect(rendered).to have_css('b', text: "dossier n°\u00a0#{dossier.id}", visible: :all)
  end

  it 'lists the service contact without a list around it (RGAA 9.3)' do
    expect(rendered).to have_css('#messagerie-close-explanations dl', visible: :all)
    expect(rendered).to have_no_css('#messagerie-close-explanations ul > dl', visible: :all)
  end
end
