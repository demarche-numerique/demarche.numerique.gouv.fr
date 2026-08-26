# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Procedure::LegacyDeclarativeEmailsNoticeComponent, type: :component do
  let(:procedure) { create(:procedure, declarative_with_state: :en_instruction) }

  before { render_inline(described_class.new(procedure:)) }

  context 'when the declarative procedure was kept on the legacy emails' do
    let(:procedure) do
      create(:procedure, declarative_with_state: :en_instruction).tap do |procedure|
        procedure.update!(combined_declarative_email: false)
        create(:email_depose, procedure:)
      end
    end

    it 'offers the switch' do
      expect(page).to have_css('.fr-notice--warning', text: 'nouvelle version')
      expect(page).to have_button('En savoir plus')
      expect(page).to have_css("form[action='#{Rails.application.routes.url_helpers.switch_to_combined_admin_procedure_email_templates_path(procedure)}']")
    end
  end

  context 'when the procedure already sends the combined email' do
    it 'renders nothing' do
      expect(page).not_to have_css('.fr-notice')
    end
  end
end
