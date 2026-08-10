# frozen_string_literal: true

RSpec.describe Referentiels::StepperComponent, type: :component do
  let(:referentiel) { create(:api_referentiel, :exact_match) }
  let(:procedure) { create(:procedure, types_de_champ_public:, types_de_champ_private:) }
  let(:types_de_champ_public) { [] }
  let(:types_de_champ_private) { [] }
  let(:step_component) do
    Referentiels::MappingFormComponent.new(
      referentiel:,
      type_de_champ:,
      procedure:
    )
  end

  subject(:rendered_component) { render_inline(described_class.new(step_component:)) }

  context 'when referentiel is private' do
    let(:type_de_champ) { procedure.draft_revision.root_private_types_de_champ.first }
    let(:types_de_champ_private) { [{ type: :referentiel, referentiel: }] }

    it 'back links goes to annotations' do
      expect(rendered_component)
        .to have_link('Annotations privées', href: Rails.application.routes.url_helpers.annotations_admin_procedure_path(procedure))
    end
  end

  context 'when referentiel is public' do
    let(:type_de_champ) { procedure.draft_revision.root_public_types_de_champ.first }
    let(:types_de_champ_public) { [{ type: :referentiel, referentiel: }] }

    it 'back links goes to champs' do
      expect(rendered_component)
        .to have_link('Champs du formulaire', href: Rails.application.routes.url_helpers.champs_admin_procedure_path(procedure))
    end
  end
end
