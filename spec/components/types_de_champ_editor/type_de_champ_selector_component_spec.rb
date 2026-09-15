# frozen_string_literal: true

describe TypesDeChampEditor::TypeDeChampSelectorComponent, type: :component do
  let(:routing_rules_stable_ids) { [] }
  let(:ineligibilite_rules_used?) { false }
  let(:tdc) { procedure.draft_revision.type_de_champs.first }
  let(:coordinate) { procedure.draft_revision.coordinate_for(tdc) }
  let(:form) { ActionView::Helpers::FormBuilder.new(:type_de_champ, coordinate.type_de_champ, vc_test_controller.view_context, {}) }
  let(:props) { JSON.parse(page.find('react-component')['props']) }
  let(:items) { props['sections'].flat_map { it['items'] } }
  let(:values) { items.map { it['value'] } }

  before do
    allow_any_instance_of(Procedure).to receive(:stable_ids_used_by_routing_rules).and_return(routing_rules_stable_ids)
    allow_any_instance_of(ProcedureRevisionTypeDeChamp).to receive(:used_by_ineligibilite_rules?).and_return(ineligibilite_rules_used?)
    render_inline(described_class.new(coordinate:, form:))
  end

  describe 'the menu of a plain field' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text }]) }

    it 'lists the types by category, in the editor order, each with an icon' do
      expect(props['sections'].map { it['label'] }).to eq([
        'Structure du formulaire', 'Champs standards', 'Choix', 'Identification et coordonnées', 'Localisation', 'Champs automatisés FranceConnect', 'Référentiel',
      ])
      expect(props['sections'].first['items'].map { it['label'] }).to eq(['Titre de section', 'Explication'])
      expect(props['sections'].second['items'].map { it['value'] }).to start_with('text', 'textarea', 'integer_number', 'decimal_number', 'formatted')
      expect(items.map { it['icon'] }).to all(start_with('fr-icon-'))
    end

    it 'binds the select to the form field, labelled and enabled' do
      expect(props['name']).to eq('type_de_champ[type_champ]')
      expect(props['value']).to eq('text')
      expect(props['disabledKeys']).to be_empty
      expect(props['isDisabled']).to be(false)
      expect(page).to have_css("label[for=\"#{ActionView::RecordIdentifier.dom_id(tdc, :type_champ)}\"]", text: 'Type de champ')
      expect(page).not_to have_text('Aucun type de champ autorisé')
    end

    it 'leaves out the legacy number type and the types behind a disabled flag' do
      expect(values).not_to include('number', 'cojo')
    end
  end

  describe 'the legacy number type' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text }, { type: :number }]) }

    it 'stays available while the revision still has one' do
      expect(values).to include('number')
    end
  end

  describe 'a type behind an enabled feature flag' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text }]).tap { Flipper.enable(:cojo_type_de_champ, _1) } }

    it { expect(values).to include('cojo') }
  end

  describe 'public-only and private-only types' do
    let(:procedure) do
      create(:procedure, public_type_de_champs: [{ type: :text }], private_type_de_champs: [{ type: :text }])
        .tap { Flipper.enable_actor(:engagement_juridique_type_de_champ, _1) }
    end

    context 'on a public field' do
      let(:coordinate) { procedure.draft_revision.public_revision_type_de_champs.first }

      it do
        expect(values).to include('quotient_familial')
        expect(values).not_to include('engagement_juridique')
      end
    end

    context 'on a private field' do
      let(:coordinate) { procedure.draft_revision.private_revision_type_de_champs.first }

      it do
        expect(values).to include('engagement_juridique')
        expect(values).not_to include('quotient_familial')
      end
    end

    context 'on a field inside a repetition' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :repetition, children: [{ type: :text }] }]) }
      let(:coordinate) { procedure.draft_revision.public_revision_type_de_champs.first.children_revision_type_de_champs.first }

      it { expect(values).not_to include('quotient_familial', 'repetition') }
    end
  end

  describe 'a field used by rules' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :drop_down_list, libelle: 'Votre ville', options: ['Paris', 'Lyon'] }]) }

    context 'routing rules' do
      let(:routing_rules_stable_ids) { [tdc.stable_id] }

      it 'locks the menu' do
        expect(props['isDisabled']).to be(true)
        expect(page).to have_text('Aucun type de champ autorisé pour transformer ce champ')
      end
    end

    context 'eligibility rules' do
      let(:ineligibilite_rules_used?) { true }

      it 'locks the menu' do
        expect(props['isDisabled']).to be(true)
        expect(page).to have_text('Aucun type de champ autorisé pour transformer ce champ')
      end
    end
  end

  describe 'a field of a published procedure' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :date }]) }

    it 'greys out the types the field cannot be converted to' do
      expect(props['isDisabled']).to be(false)
      expect(props['disabledKeys']).to include('integer_number', 'drop_down_list')
      expect(props['disabledKeys']).not_to include('date', 'datetime', 'text')
    end

    context 'when no conversion is allowed' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :piece_justificative }]) }

      it 'locks the menu' do
        expect(props['isDisabled']).to be(true)
        expect(page).to have_text('Aucun type de champ autorisé pour transformer ce champ')
      end
    end
  end

  describe 'ACCEPTED_TYPES' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text }]) }

    it 'contains expected conversions' do
      expect(described_class::ACCEPTED_TYPES).to include(
        "checkbox" => ["yes_no", "text", "textarea", "formatted"],
        "civilite" => ["text", "textarea", "formatted"],
        "communes" => ["text", "textarea", "formatted"],
        "date" => ["datetime", "text", "textarea", "formatted"],
        "datetime" => ["date", "text", "textarea", "formatted"],
        "decimal_number" => ["integer_number", "text", "textarea", "formatted"],
        "drop_down_list" => ["multiple_drop_down_list", "text", "textarea", "formatted", "pre_rempli"],
        "email" => ["text", "textarea", "formatted"],
        "formatted" => ["textarea", "text", "email", "phone", "pre_rempli"],
        "integer_number" => ["decimal_number", "text", "textarea", "formatted"],
        "multiple_drop_down_list" => ["drop_down_list", "text", "textarea", "formatted"],
        "phone" => ["text", "textarea", "formatted"],
        "pre_rempli" => ["text", "textarea", "formatted", "drop_down_list"],
        "text" => ["textarea", "formatted", "email", "phone", "decimal_number", "integer_number", "pre_rempli"],
        "textarea" => ["text", "formatted", "pre_rempli"],
        "yes_no" => ["checkbox", "text", "textarea", "formatted"]
      )
    end
  end
end
