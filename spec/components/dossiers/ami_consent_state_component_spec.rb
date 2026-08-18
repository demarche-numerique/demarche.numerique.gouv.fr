# frozen_string_literal: true

RSpec.describe Dossiers::AmiConsentStateComponent, type: :component do
  subject(:render_component) { render_inline(described_class.new(status:, **options)) }

  let(:options) { {} }

  context 'while AMI has not answered yet' do
    let(:status) { :loading }

    it 'announces the loading without offering the consent yet' do
      render_component

      expect(page).to have_css('.fr-sr-only')
      expect(page).not_to have_button
    end
  end

  context 'when the user has not consented' do
    let(:status) { :not_granted }

    it 'offers to follow the procedures in the app' do
      render_component

      expect(page).to have_button(text: /Je souhaite suivre mes démarches/)
      expect(page).to have_css('.fr-icon-notification-3-line')
      expect(page).to have_css("form[action='/suivi-ami'][data-turbo='true']")
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

  context 'when the call to AMI failed' do
    let(:status) { :not_granted }
    let(:options) { { error: true } }

    it 'warns the user and keeps the consent available' do
      render_component

      expect(page).to have_css('[role="alert"]')
      expect(page).to have_button(text: /Je souhaite suivre mes démarches/)
    end
  end
end
