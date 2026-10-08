# frozen_string_literal: true

require "rails_helper"

RSpec.describe Instructeurs::EditDossierConfirmComponent, type: :component do
  let(:modal_html) { rendered_content }

  before do
    with_request_url "/procedures/#{dossiers.en_construction.procedure.id}/dossiers/#{dossiers.en_construction.id}" do
      render_inline(described_class.new(dossier: dossiers.en_construction))
    end
  end

  it_behaves_like 'a labelled DSFR modal', 'dossier-submit-dialog'
  it { expect(page).to have_css('dialog#dossier-submit-dialog[data-controller="auto-open-modal"]', visible: :all) }
end
