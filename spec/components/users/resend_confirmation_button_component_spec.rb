# frozen_string_literal: true

RSpec.describe Users::ResendConfirmationButtonComponent, type: :component do
  let(:locale) { :fr }

  before { I18n.with_locale(locale) { render_inline(described_class.new(seconds_remaining:)) } }

  context 'while the delay runs' do
    let(:seconds_remaining) { 119 }

    it 'renders the button enabled with its plain label' do
      expect(page).to have_button(exact_text: 'Renvoyer un email de confirmation', disabled: false)
    end

    it 'hands the countdown its labels' do
      wrapper = page.find('[data-controller="countdown-button"]')
      expect(wrapper['data-countdown-button-seconds-value']).to eq('119')
      expect(wrapper['data-countdown-button-one-value']).to eq('Renvoyer un email de confirmation (1 seconde)')
      expect(wrapper['data-countdown-button-other-value']).to eq('Renvoyer un email de confirmation (# secondes)')
      expect(wrapper['data-countdown-button-label-value']).to eq('Renvoyer un email de confirmation')
      expect(wrapper['data-countdown-button-available-value']).to eq('Vous pouvez maintenant renvoyer l’email de confirmation.')
      expect(wrapper['data-action']).to eq('visibilitychange@document->countdown-button#refresh pageshow@window->countdown-button#restore')
      expect(page.find('[role="status"].fr-sr-only').text).to be_empty
      expect(page).to have_css('button[data-countdown-button-target="button"]')
      expect(page).to have_css('[role="status"][data-countdown-button-target="status"]')
    end
  end

  context 'when nothing was requested lately' do
    let(:seconds_remaining) { 0 }

    it { expect(page).to have_button(exact_text: 'Renvoyer un email de confirmation', disabled: false) }
  end

  context 'in english' do
    let(:locale) { :en }
    let(:seconds_remaining) { 5 }

    it 'renders the button enabled with its plain label and hands the countdown its labels' do
      expect(page).to have_button(exact_text: 'Resend the confirmation email', disabled: false)
      expect(page.find('[data-controller="countdown-button"]')['data-countdown-button-other-value']).to eq('Resend the confirmation email (# seconds)')
    end
  end
end
