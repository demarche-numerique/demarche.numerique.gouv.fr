# frozen_string_literal: true

RSpec.describe Dossiers::AmiConsentStateComponent, type: :component do
  subject(:render_component) { render_inline(described_class.new(status:, dossier:, **options)) }

  let(:dossier) { dossiers.en_construction }
  let(:options) { {} }

  context 'while AMI has not answered yet' do
    let(:status) { :loading }

    it 'announces the loading without offering the consent yet' do
      render_component

      expect(page).to have_css('.fr-sr-only')
      expect(page).not_to have_button
    end

    it 'holds the place with a skeleton, hidden from assistive technologies' do
      render_component

      expect(page).to have_css('.ami-consent__skeleton[aria-hidden="true"]')
    end
  end

  context 'when AMI cannot be asked at all' do
    let(:status) { :unavailable }

    it 'renders nothing, leaving the frame empty' do
      render_component

      expect(page).not_to have_button
      expect(page).not_to have_css('p')
    end
  end

  context 'when the user has not consented' do
    let(:status) { :not_granted }

    it 'offers to follow the procedures in the app' do
      render_component

      expect(page).to have_button(text: /Je souhaite suivre mes démarches/)
      expect(page).to have_css('.fr-icon-notification-3-line')
      expect(page).to have_css("form[action='/dossiers/#{dossier.id}/ami-consent'][data-turbo='true']")
    end
  end

  context 'when the consent could not be saved' do
    let(:status) { :error }

    it 'says so and lets the user try again' do
      render_component

      expect(page).to have_css('.fr-error-text')
      expect(page).to have_button(text: /Je souhaite suivre mes démarches/)
    end
  end

  context 'when AMI could not answer' do
    let(:status) { :unknown }

    it 'falls back on offering the consent' do
      render_component

      expect(page).to have_button(text: /Je souhaite suivre mes démarches/)
    end
  end

  context 'when the user has consented' do
    let(:status) { :granted }

    it 'confirms the follow-up instead of offering it' do
      render_component

      expect(page).to have_text('Vous suivez vos démarches')
      expect(page).to have_css('.fr-icon-check-line')
      expect(page).not_to have_button
    end

    it 'does not steal the focus on page load' do
      render_component

      expect(page).not_to have_css('[data-controller="autofocus"]')
    end

    context 'right after the user consented' do
      let(:options) { { focus: true } }

      it 'moves the focus to the confirmation' do
        render_component

        expect(page).to have_css('[data-controller="autofocus"][tabindex="-1"]')
      end
    end
  end
end
