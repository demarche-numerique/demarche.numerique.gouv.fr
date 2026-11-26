# frozen_string_literal: true

RSpec.describe Dossiers::DeletedDossiersComponent, type: :component do
  let(:deleted_dossier) { create(:deleted_dossier, procedure: procedures.individual, deleted_at: Time.zone.local(2026, 12, 1, 14, 5)) }

  subject(:rendered) { render_inline(described_class.new(deleted_dossiers: DeletedDossier.where(id: deleted_dossier.id).page(1))) }

  it 'dates the deletion in French' do
    expect(rendered).to have_selector('td.deleted-cell', text: '01/12/2026')
  end

  it 'dates the deletion in English' do
    I18n.with_locale(:en) { expect(rendered).to have_selector('td.deleted-cell', text: '1 Dec 2026') }
  end
end
