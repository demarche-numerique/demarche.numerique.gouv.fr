# frozen_string_literal: true

describe EditableChamp::RNFComponent, type: :component do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :rnf, libelle: 'Numéro RNF' }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champ_data.first }

  def render_full_champ
    component = nil
    ActionView::Base.empty.form_for(champ, url: '/') do |form|
      component = EditableChamp::EditableChampComponent.new(champ:, form:)
    end
    render_inline(component)
  end

  context 'when the RNF lookup failed and the dossier has been validated' do
    before do
      champ.update_columns(external_id: '075-FDD-00003-0', external_state: 'external_error')
      champ.send(:save_external_error, StandardError.new('NotFound'), 404)
      champ.reload
      dossier.validate(:public_champs_value)
    end

    it 'renders a single error message (no duplicate status text)' do
      render_full_champ

      expect(page).to have_css('.fr-message--error', text: 'Résultat introuvable', count: 1)
      expect(page).to have_no_text('Aucune fondation trouvée')
    end
  end
end
