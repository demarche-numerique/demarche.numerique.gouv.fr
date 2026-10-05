# frozen_string_literal: true

require "rails_helper"

RSpec.describe Instructeurs::ProceduresDossiersSyntheseButtonComponent, type: :component do
  let(:modal_html) { rendered_content }

  before { render_inline(described_class.new(procedures_count: 2)) }

  it_behaves_like 'a labelled DSFR modal', 'synthese-modal'
  it { expect(page).to have_css('dialog#synthese-modal turbo-frame#synthese-content[data-lazy-modal-target="frame"]', visible: :all) }
end
