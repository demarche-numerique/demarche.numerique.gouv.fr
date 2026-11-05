# frozen_string_literal: true

RSpec.describe Users::ResendConfirmationButtonComponent, type: :component do
  let(:locale) { :fr }

  before { I18n.with_locale(locale) { render_inline(described_class.new(seconds_remaining:)) } }

  context 'while the delay runs' do
    let(:seconds_remaining) { 119 }

    it 'renders the button enabled with its plain label and an empty counter' do
      expect(page).to have_button(exact_text: 'Renvoyer un email de confirmation', disabled: false)
      expect(page).to have_css('button > span', count: 1)
      expect(page.find('button > span > span[aria-hidden="true"][data-countdown-button-target="counter"]').text).to be_empty
    end

    it 'hands the countdown its labels' do
      wrapper = page.find('[data-controller="countdown-button"]')
      expect(wrapper['data-countdown-button-seconds-value']).to eq('119')
      expect(wrapper['data-countdown-button-counter-one-value']).to eq('(1 seconde)')
      expect(wrapper['data-countdown-button-counter-other-value']).to eq('(# secondes)')
      expect(wrapper['data-countdown-button-announcement-one-value']).to eq('Renvoi de l’email possible dans 1 seconde.')
      expect(wrapper['data-countdown-button-announcement-other-value']).to eq('Renvoi de l’email possible dans # secondes.')
      expect(wrapper['data-countdown-button-available-value']).to eq('Vous pouvez maintenant renvoyer l’email de confirmation.')
      expect(wrapper['data-action']).to eq('visibilitychange@document->countdown-button#refresh pageshow@window->countdown-button#restore')
      expect(page.find('[role="status"].fr-sr-only').text).to be_empty
      expect(page).to have_css('button[data-countdown-button-target="button"]')
      expect(page).to have_css('[role="status"][data-countdown-button-target="status"]')
    end
  end

  context 'in english' do
    let(:locale) { :en }
    let(:seconds_remaining) { 5 }

    it 'renders the button enabled with its plain label and hands the countdown its labels' do
      expect(page).to have_button(exact_text: 'Resend the confirmation email', disabled: false)
      wrapper = page.find('[data-controller="countdown-button"]')
      expect(wrapper['data-countdown-button-counter-other-value']).to eq('(# seconds)')
      expect(wrapper['data-countdown-button-announcement-other-value']).to eq('You can resend the email in # seconds.')
    end
  end
end
