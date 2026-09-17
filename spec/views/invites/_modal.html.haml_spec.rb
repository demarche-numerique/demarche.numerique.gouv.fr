# frozen_string_literal: true

describe 'invites/_modal', type: :view do
  let(:dossier) { create(:dossier, :en_construction) }
  let(:invite) { dossier.invites.build }
  let(:invites) { [] }

  before do
    # Stub the form_wrapper partial since it doesn't exist
    stub_template 'invites/_form_wrapper.html.haml' => '<div>form content</div>'
  end

  subject! { render partial: 'invites/modal', locals: { dossier: dossier, invite: invite, invites: invites } }

  describe 'accessibility' do
    it 'has role="dialog" attribute on the modal for screen readers' do
      expect(rendered).to have_selector('dialog#modal-invite[role="dialog"]')
    end

    it 'has aria-labelledby attribute pointing to the modal title' do
      expect(rendered).to have_selector('dialog#modal-invite[aria-labelledby="modal-invite-title"]')
    end
  end
end
