# frozen_string_literal: true

describe 'invites/_button', type: :view do
  let(:dossier) { create(:dossier, :en_construction) }

  subject! { render partial: 'invites/button', locals: { dossier: dossier } }

  describe 'accessibility' do
    it 'has role="dialog" attribute on the placeholder modal for screen readers' do
      expect(rendered).to have_selector('dialog#dossier-invites-modal-dialog[role="dialog"]')
    end
  end
end
