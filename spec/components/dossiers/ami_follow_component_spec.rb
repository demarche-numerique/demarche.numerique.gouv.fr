# frozen_string_literal: true

RSpec.describe Dossiers::AmiFollowComponent, type: :component do
  subject(:render_component) { render_inline(described_class.new(dossier:)) }

  let(:dossier) { dossiers.en_construction }

  before do
    allow_any_instance_of(Procedure).to receive(:feature_enabled?).with(:ami_notifications).and_return(true)
    allow(Ami::RecipientFcHash).to receive(:call).and_return("abc123")
  end

  it 'promotes the app and offers to download it' do
    render_component

    expect(page).to have_css('.ami-follow')
    expect(page).to have_text(Ami::APP_NAME)
    expect(page).to have_link(href: Ami::APP_URL)
    expect(page).to have_css("a[target='_blank'][rel='noopener noreferrer']")
  end

  it 'loads the consent state aside from the page' do
    render_component

    expect(page).to have_css("turbo-frame#ami-consent[src='/suivi-ami'][loading='lazy']")
  end

  it 'opens the app information in a modal' do
    render_component

    expect(page).to have_css("button[aria-controls='ami-info-modal'][aria-haspopup='dialog']")
    expect(page).to have_css('dialog#ami-info-modal.fr-modal')
  end

  context 'when previewing the page as an administrateur, without a dossier' do
    let(:dossier) { nil }

    it 'renders nothing' do
      render_component

      expect(page).not_to have_css('.ami-follow')
    end
  end

  context 'when the procedure does not send AMI notifications' do
    before { allow_any_instance_of(Procedure).to receive(:feature_enabled?).with(:ami_notifications).and_return(false) }

    it 'renders nothing' do
      render_component

      expect(page).not_to have_css('.ami-follow')
    end
  end

  context 'when the user has no France Connect identity' do
    before { allow(Ami::RecipientFcHash).to receive(:call).and_return(nil) }

    it 'renders nothing' do
      render_component

      expect(page).not_to have_css('.ami-follow')
    end
  end
end
