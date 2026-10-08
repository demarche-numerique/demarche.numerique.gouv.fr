# frozen_string_literal: true

describe TagsLegendModalComponent, type: :component do
  let(:modal_html) { rendered_content }

  before { render_inline(described_class.new(modal_id: 'tags-legend')) }

  it_behaves_like 'a labelled DSFR modal', 'tags-legend'

  it { expect(page).to have_css('dialog#tags-legend.tags-legend-modal', visible: :all) }
end
