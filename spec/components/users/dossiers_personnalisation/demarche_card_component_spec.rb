# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::DossiersPersonnalisation::DemarcheCardComponent, type: :component do
  let(:procedure) { create(:procedure, :published, libelle: 'Aide presse', types_de_champ_public: [{ type: :text, libelle: 'Titre' }]) }
  let(:user) { create(:user) }
  let(:presentation) { UserProcedurePresentation.new(user:, procedure:) }

  it 'rend le titre de la démarche' do
    render_inline(described_class.new(procedure:, presentation:))
    expect(page).to have_content('Aide presse')
  end

  it 'rend la mention par défaut si aucun champ sélectionné' do
    render_inline(described_class.new(procedure:, presentation:))
    expect(page).to have_content(I18n.t('users.dossiers_personnalisation.edit.affichage_non_personnalise'))
  end

  it 'rend un MultiComboBox configuré avec le stable_id en items' do
    render_inline(described_class.new(procedure:, presentation:))
    expect(page).to have_css('react-fragment')
  end
end
