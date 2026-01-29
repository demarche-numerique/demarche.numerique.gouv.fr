# frozen_string_literal: true

describe 'invites/index', type: :view do
  let(:dossier) { create(:dossier, :en_construction) }

  before do
    assign(:dossier, dossier)
  end

  subject! { render }

  describe 'accessibility' do
    it 'has role="dialog" attribute on the modal for screen readers' do
      expect(rendered).to have_selector('dialog#dossier-invites-modal-dialog[role="dialog"]')
    end

    it 'has aria-labelledby attribute pointing to the modal title' do
      expect(rendered).to have_selector('dialog#dossier-invites-modal-dialog[aria-labelledby="dossier-invites-modal-title"]')
    end
  end
end
