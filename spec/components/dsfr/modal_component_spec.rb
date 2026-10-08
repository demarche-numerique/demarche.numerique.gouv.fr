# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dsfr::ModalComponent, type: :component do
  let(:options) { {} }
  let(:with_title) { true }
  let(:with_footer) { false }
  let(:modal_html) { rendered_content }

  before do
    render_inline(described_class.new(id: 'my-modal', **options)) do |modal|
      modal.with_title { 'Mon titre' } if with_title
      modal.with_footer { 'Mon pied' } if with_footer
      'Mon contenu'
    end
  end

  it_behaves_like 'a labelled DSFR modal', 'my-modal'

  it 'renders the DSFR skeleton with a typed close button' do
    expect(page).to have_css('dialog#my-modal.fr-modal[role="dialog"] .fr-container.fr-container--fluid.fr-container-md .fr-grid-row--center .fr-col-12.fr-col-md-8.fr-col-lg-6 .fr-modal__body')
    expect(page).to have_button('Fermer', title: 'Fermer', type: 'button')
    expect(page).to have_css('button.fr-btn--close[aria-controls="my-modal"]')
    expect(page).to have_css('.fr-modal__content', text: 'Mon contenu')
    expect(page).to have_no_css('.fr-modal__footer')
  end

  it 'prefixes the title with a decorative icon' do
    expect(page).to have_css('h2.fr-modal__title > span.fr-icon-arrow-right-line.fr-icon--lg[aria-hidden="true"]')
  end

  context 'with a size' do
    let(:options) { { size: :lg } }

    it { expect(page).to have_css('.fr-col-12.fr-col-md-10.fr-col-lg-8') }
  end

  context 'with an unknown size' do
    it 'raises' do
      expect { described_class.new(id: 'x', size: :xl) }.to raise_error(ArgumentError, /unknown modal size: xl/)
    end
  end

  context 'without icon' do
    let(:options) { { icon: nil } }

    it { expect(page).to have_no_css('h2.fr-modal__title span') }
  end

  context 'with a hidden title' do
    let(:options) { { title_hidden: true } }

    it { expect(page).to have_css('h2#my-modal-title.fr-modal__title.fr-sr-only', visible: :all) }
  end

  context 'without title slot' do
    let(:with_title) { false }

    it 'leaves the h2 to the caller but keeps the label reference' do
      expect(page).to have_no_css('h2')
      expect(page).to have_css('dialog[aria-labelledby="my-modal-title"]')
    end
  end

  context 'with a footer' do
    let(:with_footer) { true }

    it { expect(page).to have_css('.fr-modal__body > .fr-modal__footer', text: 'Mon pied') }
  end

  context 'with html attributes' do
    let(:options) do
      {
        class: 'tags-legend-modal',
        role: 'alertdialog',
        aria: { describedby: 'my-description' },
        data: { controller: 'auto-open-modal', 'turbo-permanent': true },
      }
    end

    it 'merges them with its own' do
      expect(page).to have_css('dialog#my-modal.fr-modal.tags-legend-modal[role="alertdialog"][aria-labelledby="my-modal-title"][aria-describedby="my-description"][data-controller="auto-open-modal"][data-turbo-permanent]')
    end
  end

  context 'with html attributes trying to override the label' do
    let(:options) { { aria: { labelledby: 'other', describedby: 'my-description' } } }

    it 'keeps the dialog labelled by its own title' do
      expect(page).to have_css('dialog#my-modal[aria-labelledby="my-modal-title"][aria-describedby="my-description"]')
    end
  end
end
