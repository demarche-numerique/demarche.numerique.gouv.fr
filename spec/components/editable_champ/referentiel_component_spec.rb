# frozen_string_literal: true

require 'rails_helper'

describe EditableChamp::ReferentielComponent, type: :component do
  let(:types_de_champ_public) { [{ type: :referentiel, referentiel:, referentiel_mapping: {} }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:champ) { dossier.project_champs_public.first }
  let(:form) do
    ActionView::Helpers::FormBuilder.new("dossier[champs_public_attributes]", champ, ActionController::Base.new.view_context, {})
  end

  let(:component) { described_class.new(form:, champ:) }
  subject { render_inline(component) }

  context 'when referentiel is nil' do
    let(:referentiel) { nil }

    it 'renders a disabled input without crashing' do
      expect(subject).to have_field(type: 'text', disabled: true)
    end

    it 'does not render the autocomplete combobox' do
      expect(subject).not_to have_selector('react-fragment')
    end
  end

  context 'when referentiel is present' do
    let(:referentiel) { create(:api_referentiel, :autocomplete) }

    it 'renders the autocomplete combobox' do
      expect(subject).to have_selector('react-fragment')
    end

    it 'includes dossier_id in loader URL' do
      expect(subject.to_html).to include("dossier_id=#{dossier.id}")
    end

    it 'renders a non-blocking info message when external data is in technical error' do
      allow(champ).to receive(:external_data_status_message).and_return(:technical_error)
      expect(subject).to have_text(I18n.t('shared.champs.external_data.technical_error'))
    end

    it 'renders no info message when external data is fetched' do
      allow(champ).to receive(:external_data_status_message).and_return(nil)
      expect(subject).not_to have_text(I18n.t('shared.champs.external_data.technical_error'))
    end
  end
end
