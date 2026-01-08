# frozen_string_literal: true

describe 'shared/dossiers/edit', type: :view do
  before do
    allow(controller).to receive(:current_user).and_return(dossier.user)
    allow(view).to receive(:administrateur_signed_in?).and_return(false)
  end

  subject { render 'shared/dossiers/edit', dossier:, apercu: false }

  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }

  context 'when there are some champs' do
    let(:type_de_champ_header_section) { procedure.draft_types_de_champ_public.find(&:header_section?) }
    let(:type_de_champ_explication) { procedure.draft_types_de_champ_public.find(&:explication?) }
    let(:type_de_champ_dossier_link) { procedure.draft_types_de_champ_public.find(&:dossier_link?) }
    let(:type_de_champ_checkbox) { procedure.draft_types_de_champ_public.find(&:checkbox?) }
    let(:type_de_champ_textarea) { procedure.draft_types_de_champ_public.find(&:textarea?) }

    let(:champ_checkbox) { dossier.project_champ(type_de_champ_checkbox) }
    let(:champ_dossier_link) { dossier.project_champ(type_de_champ_dossier_link) }
    let(:champ_textarea) { dossier.project_champ(type_de_champ_textarea) }

    let(:types_de_champ_public) { [{ type: :checkbox }, { type: :header_section }, { type: :explication }, { type: :dossier_link }, { type: :textarea }] }

    it 'renders labels and editable values of champs' do
      expect(subject).to have_field(champ_checkbox.libelle, checked: true)
      expect(subject).to have_css(".header-section", text: type_de_champ_header_section.libelle)
      expect(subject).to have_text(type_de_champ_explication.libelle)
      expect(subject).to have_field(type_de_champ_dossier_link.libelle, with: champ_dossier_link.value)
      expect(subject).to have_field(champ_textarea.libelle, with: champ_textarea.value)
    end

    context "with standard champs" do
      let(:types_de_champ_public) { [{ type: :email }, { type: :phone }] }

      it "does not render basic placeholders" do
        expect(subject).not_to have_css('input[type="email"][placeholder$="exemple.fr"]')
        expect(subject).not_to have_css('input[type="tel"][placeholder^="0612"]')
      end
    end
  end

  context 'with a public text champ containing HTML in value' do
    let(:types_de_champ_public) { [{ type: :textarea }] }
    let(:procedure) { create(:procedure, types_de_champ_public:) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.project_champs_public.first }

    before do
      champ.update(value: 'This <strong>should be escaped</strong>')
    end

    it 'renders the value escaped in the input' do
      expect(subject).not_to include('<strong>should be escaped</strong>'.html_safe)
      expect(subject).to include('This &lt;strong&gt;should be escaped&lt;/strong&gt;')
    end
  end

  context 'with a single-value list' do
    let(:types_de_champ_public) { [{ type: :drop_down_list, options:, mandatory: }] }
    let(:champ) { dossier.project_champs_public.first }
    let(:type_de_champ) { champ.type_de_champ }
    let(:enabled_options) { type_de_champ.drop_down_options }
    let(:mandatory) { true }
    let(:options) { nil }

    context 'when the list is short' do
      let(:value) { 'val1' }

      before { champ.update(value:) }

      it 'renders the list as radio buttons' do
        expect(subject).to have_selector('input[type=radio]', count: enabled_options.count)
      end

      context 'when the champ is optional' do
        let(:mandatory) { false }

        it 'allows unselecting a previously selected value' do
          expect(subject).to have_selector('input[type=radio]', count: enabled_options.count + 1)
          expect(subject).to have_unchecked_field('Non renseigné', count: 1)
        end
      end
    end

    context 'when the list is long' do
      let(:value) { 'alpha' }
      let(:options) { ['1', '2', '3', '4', '5', '6'] }

      before { champ.update(value:) }

      it 'renders the list as a dropdown' do
        expect(subject).to have_select(type_de_champ.libelle, options: enabled_options)
      end
    end
  end

  context 'with a multiple-values list' do
    let(:types_de_champ_public) { [{ type: :multiple_drop_down_list, options: }] }
    let(:champ) { dossier.champs.first }
    let(:type_de_champ) { champ.type_de_champ }
    let(:options) { type_de_champ.drop_down_options }
    let(:enabled_options) { type_de_champ.drop_down_options }

    context 'when the list is short' do
      let(:options) { ['valid', 'invalid', 'not sure yet'] }

      it 'renders the list as checkboxes' do
        expect(subject).to have_selector('input[type=checkbox]', count: enabled_options.count)
        expect(subject).to have_selector('input[type=checkbox][checked=checked]', count: 2)
      end

      it 'adds an extra hidden input, to send a blank value even when all checkboxes are unchecked' do
        expect(subject).to have_selector('input[type=hidden][value=""]')
      end
    end

    context 'when the list is long' do
      let(:options) { ['peach', 'banana', 'pear', 'apricot', 'apple', 'grapefruit'] }

      it 'renders the list as a multiple-selection dropdown' do
        expect(subject).to have_selector('react-fragment > react-component[name="Select/MultipleSelect"]')
      end
    end
  end

  context 'with a mandatory piece justificative' do
    let(:types_de_champ_public) { [{ type: :piece_justificative, mandatory: true }] }
    let(:champ) { dossier.champs.first }

    context 'when dossier is en construction (stream)' do
      let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:).then { |dossier| dossier.with_update_stream(dossier.user) } }

      it 'can delete a piece justificative' do
        expect(subject).to have_selector("[title='Supprimer le fichier #{champ.piece_justificative_file.attachments[0].filename}']")
      end
    end

    context 'when dossier is brouillon' do
      it 'can delete a piece justificative' do
        expect(subject).to have_selector("[title='Supprimer le fichier #{champ.piece_justificative_file.attachments[0].filename}']")
      end
    end
  end

  context 'with a routed procedure' do
    let(:groupe_instructeur) { create(:groupe_instructeur) }
    let(:procedure) { create(:procedure, :routee, groupe_instructeurs: [groupe_instructeur], types_de_champ_public: [{ type: :drop_down_list, options: }]) }
    let(:options) { [groupe_instructeur.label] }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ_drop_down) { dossier.champs.first }

    it 'renders the libelle of the type de champ used for routing' do
      expect(subject).to include(champ_drop_down.libelle)
    end

    context 'when groupe instructeur is selected' do
      before do
        dossier.groupe_instructeur = dossier.procedure.defaut_groupe_instructeur
      end

      it 'renders the routing libelle and its value' do
        expect(subject).to include(champ_drop_down.libelle)
        expect(subject).to include(dossier.groupe_instructeur.label)
      end
    end
  end

  context 'when dossier transitions rules are computable and passer_en_construction is false' do
    let(:types_de_champ_public) { [] }
    let(:dossier) { create(:dossier, procedure:) }

    before do
      allow(dossier).to receive(:can_passer_en_construction?).and_return(false)
      allow(dossier.revision).to receive(:ineligibilite_enabled?).and_return(true)
    end

    it 'renders broken transitions rules dialog' do
      expect(subject).to have_selector("#ineligibilite_rules_modal [data-fr-opened='true']")
    end
  end
end
