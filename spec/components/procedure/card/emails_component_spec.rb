# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Procedure::Card::EmailsComponent, type: :component do
  let(:procedure) { create(:procedure) }

  before { render_inline(described_class.new(procedure:)) }

  context 'when no email template is customized' do
    it 'shows the default configuration badge' do
      expect(page).to have_css('p.fr-badge', text: 'Configurés par défaut')
      expect(page).to have_no_css('.fr-badge--info')
      expect(page).to have_css('.fr-tag', text: '0 / 6')
    end
  end

  context 'when at least one email template is customized' do
    let(:procedure) { create(:procedure).tap { create(:email_depose, procedure: it) } }

    it 'shows the configured badge' do
      expect(page).to have_css('p.fr-badge.fr-badge--info', text: 'Configurés')
      expect(page).to have_css('.fr-tag', text: '1 / 6')
    end
  end

  context 'when the customized email template is a declarative variant' do
    let(:procedure) { create(:procedure, declarative_with_state: :accepte).tap { create(:email_depose_et_accepte, procedure: it) } }

    it 'counts it as customized' do
      expect(page).to have_css('.fr-tag', text: '1 / 6')
    end
  end

  context 'when the only customized template is left over by a previous setting' do
    let(:procedure) { create(:procedure, declarative_with_state: :accepte).tap { create(:email_depose, procedure: it) } }

    it 'counts the templates the procedure actually sends' do
      expect(page).to have_css('.fr-tag', text: '0 / 6')
    end
  end

  context 'when the repasse en instruction email has a validation error' do
    let(:procedure) { create(:procedure).tap { it.errors.add(:email_repasse_en_instruction, :invalid) } }

    it 'shows the à modifier badge' do
      expect(page).to have_css('p.fr-badge.fr-badge--warning', text: 'À modifier')
    end
  end
end
