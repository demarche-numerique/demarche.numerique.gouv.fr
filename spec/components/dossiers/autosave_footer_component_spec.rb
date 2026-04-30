# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dossiers::AutosaveFooterComponent, type: :component do
  subject(:component) { render_inline(described_class.new(dossier:, annotation:, owner:)) }

  let(:dossier) { create(:dossier) }
  let(:annotation) { false }
  let(:owner) { create(:user) }

  it 'renders data attributes for Stimulus values' do
    div = component.css('.autosave').first
    expect(div['data-autosave-status-dossier-id-value']).to eq(dossier.id.to_s)
    expect(div['data-autosave-status-contact-path-value']).to eq('/contact')
  end

  context 'when showing brouillon state (default state)' do
    it 'displays brouillon explanation' do
      expect(component).to have_text("Enregistrement automatique du dossier")
    end

    it 'renders server error template with contact link' do
      template = component.css('template[data-autosave-status-target="serverErrorTemplate"]').first
      expect(template.inner_html).to include('contactez-nous')
      expect(template.inner_html).to include('data-error-id')
    end

    it 'renders auth error template with reconnection link to current page' do
      template = component.css('template[data-autosave-status-target="authErrorTemplate"]').first
      # in component spec request.path is empty but in real world,
      # it stores after signin path, and redirects to sign in page
      expect(template.inner_html).to have_link("", text: 'vous reconnecter')
    end

    it 'renders network error template' do
      template = component.css('template[data-autosave-status-target="networkErrorTemplate"]').first
      expect(template.inner_html).to include('connexion Internet')
    end
  end

  context 'when editing fork and can pass en construction' do
    let(:dossier) { create(:dossier, :en_construction) }

    it 'displays en construction explanation' do
      expect(component).to have_text("Enregistrement automatique des modifications")
    end

    it 'renders error templates with modifications wording' do
      template = component.css('template[data-autosave-status-target="serverErrorTemplate"]').first
      expect(template.inner_html).to include('les modifications')
    end
  end

  context 'when showing annotations' do
    let(:annotation) { true }

    it 'displays annotations explanation' do
      expect(component).to have_text("Enregistrement automatique des annotations")
    end

    it 'renders error templates with annotations wording' do
      template = component.css('template[data-autosave-status-target="serverErrorTemplate"]').first
      expect(template.inner_html).to include('les annotations')
    end
  end
end
