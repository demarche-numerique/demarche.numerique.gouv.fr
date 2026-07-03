# frozen_string_literal: true

RSpec.describe Instructeurs::OCRViewerComponent, type: :component do
  let(:champ) { double('champ', ocr_result: doc, dossier_id:, id: champ_id) }
  let(:component) { described_class.new(champ:) }

  let(:dossier_id) { 1 }
  let(:champ_id) { 'champ-id-123' }

  describe '#render?' do
    context 'when doc is present' do
      let(:doc) { RIB.new(account_holder: 'John Doe', iban: 'FR76', bic: 'ABCD', bank_name: 'Test Bank') }

      it { expect(component.render?).to be true }
    end

    context 'when doc is not present' do
      let(:doc) { nil }

      it { expect(component.render?).to be false }
    end
  end

  describe 'rendering with RIB' do
    subject { render_inline(component) }

    let(:doc) { RIB.new(account_holder:, iban:, bic:, bank_name:) }
    let(:account_holder) { 'John Doe' }
    let(:iban) { 'FR7612345678901234567890123' }
    let(:bic) { 'ABCD1234' }
    let(:bank_name) { 'Banque de Test' }

    context 'when data is complete' do
      it 'renders all RIB data' do
        expect(subject).to have_css('.champ-content', text: 'John Doe')
        expect(subject).to have_css('.champ-content', text: 'FR7612345678901234567890123')
        expect(subject).to have_css('.champ-content', text: 'ABCD1234')
        expect(subject).to have_css('.champ-content', text: 'Banque de Test')
      end

      it 'renders header with title and edit button' do
        expect(subject).to have_css('.fr-text-mention--grey', text: 'Données récupérées')
        expect(subject).to have_link('Modifier', href: "/instructeurs/dossiers/#{dossier_id}/champs/#{champ_id}/edit")
      end
    end

    context 'when account_holder has multiple lines' do
      let(:account_holder) { "John Doe\nCompany Name" }

      it 'formats multiline text with br tags' do
        expect(subject).to have_css('.champ-content', text: /John Doe.*Company Name/m)
      end
    end

    context 'when data is incomplete' do
      let(:account_holder) { nil }

      it 'shows processing error for missing data' do
        expect(subject).to have_text("Cette donnée n’a pas pu être récupérée")
        expect(subject).to have_css('.champ-content', text: 'FR7612345678901234567890123')
      end
    end
  end

  describe 'rendering with JustificatifDomicile' do
    subject { render_inline(component) }

    let(:doc) do
      JustificatifDomicile.new(
        beneficiary: 'Jane Smith',
        label: 'a superbe address',
        issue_date: Date.new(2026, 1, 2),
        two_ddoc: true
      )
    end

    it 'renders justificatif domicile data' do
      expect(subject).to have_css('.champ-content', text: 'Jane Smith')
      expect(subject).to have_css('.champ-content', text: 'a superbe address')
      expect(subject).to have_css('.champ-content', text: I18n.l(Date.new(2026, 1, 2), format: :short))
      expect(subject).to have_css('acronym', text: '2D-Doc')
    end

    context 'when issue_date is nil' do
      let(:doc) do
        JustificatifDomicile.new(
          beneficiary: 'Jane Smith',
          label: 'a superbe address',
          two_ddoc: true
        )
      end

      it 'does not raise and omits the date' do
        expect { subject }.not_to raise_error
        expect(subject).to have_css('.champ-content', text: 'Jane Smith')
      end
    end
  end

  describe 'rendering with AvisImpot' do
    subject { render_inline(component) }

    let(:doc) do
      AvisImpot.new(
        declarant_1: 'MICHEL JEAN',
        reference_avis: '2538A22409999',
        annee_des_revenus: 2024,
        revenu_fiscal_de_reference: 54321,
        nombre_de_parts: 2.5,
        date_mise_en_recouvrement: Date.new(2025, 7, 31),
        label: '123 rue des Piétons 38000 Grenoble',
        two_ddoc: true
      )
    end

    it 'renders avis impot data' do
      expect(subject).to have_css('.champ-content', text: 'MICHEL JEAN')
      expect(subject).to have_css('.champ-content', text: '2538A22409999')
      expect(subject).to have_css('.champ-content', text: '54321')
      expect(subject).to have_css('.champ-content', text: I18n.l(Date.new(2025, 7, 31), format: :short))
      expect(subject).to have_css('acronym', text: '2D-Doc')
    end
  end
end
