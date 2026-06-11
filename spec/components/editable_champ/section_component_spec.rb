# frozen_string_literal: true

describe EditableChamp::SectionComponent, type: :component do
  include TreeableConcern
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:types_de_champ_public) { [] }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:types_de_champ) { dossier.revision.types_de_champ_public }
  let(:component) { described_class.new(types_de_champ:, dossier:) }
  before { render_inline(component).to_html }

  context 'list of champs without an header_section' do
    let(:types_de_champ_public) { [{ type: :text }, { type: :textarea }] }

    it 'does not renders within a fieldset' do
      expect(page).to have_selector("fieldset", count: 0)
    end

    it 'renders champs' do
      expect(page).to have_selector("input[type=text]", count: 1)
      expect(page).to have_selector("textarea", count: 1)
    end
  end

  context 'list of champs with an header_section' do
    let(:types_de_champ_public) { [{ type: :header_section, level: 1 }, { type: :text }, { type: :textarea }] }

    it 'renders fieldset' do
      expect(page).to have_selector("fieldset")
      expect(page).to have_selector("legend h3")
    end

    it 'renders champs within fieldset' do
      expect(page).to have_selector("fieldset input[type=text]")
      expect(page).to have_selector("fieldset textarea")
    end
  end

  context 'list of champs without section and an header_section having champs' do
    let(:types_de_champ_public) { [{ type: :text }, { type: :header_section, level: 1 }, { type: :text }] }

    it 'renders nested champs (after an header section) within a fieldset' do
      expect(page).to have_selector("fieldset", count: 1)
      expect(page).to have_selector("fieldset legend h3")
      expect(page).to have_selector("input[type=text]", count: 2)
      expect(page).to have_selector("fieldset input[type=text]", count: 1)
    end

    it 'renders nested within its fieldset' do
      expect(page).to have_selector("input[type=text]", count: 2)
      expect(page).to have_selector("fieldset > .fr-fieldset__element input[type=text]", count: 1)
    end
  end

  context 'list of header_section without champs' do
    let(:types_de_champ_public) { [{ type: :header_section, level: 1 }, { type: :header_section, level: 2 }, { type: :header_section, level: 3 }] }

    it 'render header within fieldset' do
      expect(page).to have_selector("fieldset > legend", count: 3)
      expect(page).to have_selector("h3")
      expect(page).to have_selector("h4")
      expect(page).to have_selector("h5")
    end
  end

  context 'header_section followed by explication and another fieldset' do
    let(:types_de_champ_public) { [{ type: :header_section, level: 1 }, { type: :explication }, { type: :header_section, level: 1 }, { type: :text }] }

    it 'render fieldset, header_section, also render explication' do
      expect(page).to have_selector("h3", count: 3)
      expect(page).to have_selector("fieldset > legend > h3", count: 2)
      expect(page).to have_selector("fieldset input[type=text]", count: 1)
    end
  end

  context 'nested fieldsset' do
    let(:types_de_champ_public) { [{ type: :header_section, level: 1 }, { type: :text }, { type: :header_section, level: 2 }, { type: :textarea }] }

    it 'render nested fieldsets' do
      expect(page).to have_selector("fieldset")
      expect(page).to have_selector("legend h3")
      expect(page).to have_selector("fieldset fieldset")
      expect(page).to have_selector("fieldset fieldset legend h4")
    end

    it 'contains all champs' do
      expect(page).to have_selector("fieldset input[type=text]", count: 1)
      expect(page).to have_selector("fieldset fieldset textarea", count: 1)
    end
  end

  context 'with repetition' do
    let(:types_de_champ_public) do
      [
        { type: :header_section, level: 1 },
        {
          type: :repetition,
          libelle: 'repetition',
          children: [
            { type: :header_section, level: 1, libelle: 'child_1' },
            { type: :text, libelle: 'child_2' },
          ],
        },
      ]
    end

    it 'render nested fieldsets, increase heading level for repetition header_section' do
      expect(page).to have_selector("fieldset")
      expect(page).to have_selector("legend h3")
      expect(page).to have_selector("fieldset fieldset")
      expect(page).to have_selector("fieldset fieldset legend h4")
    end

    it 'contains as many text champ as repetition.rows' do
      expect(page).to have_selector("fieldset fieldset input[type=text]", count: dossier.project_champs_public.find(&:repetition?).rows.size)
    end
  end

  context 'persistent live region for status-bearing champs' do
    context 'with a SIRET champ' do
      let(:types_de_champ_public) { [{ type: :siret }] }

      it 'renders a persistent sr-only polite live region' do
        champ = dossier.project_champs_public.first
        expect(page).to have_css("##{champ.focusable_input_id}-aria-live.fr-sr-only[aria-live='polite']", visible: :all)
      end
    end

    context 'with a plain text champ' do
      let(:types_de_champ_public) { [{ type: :text }] }

      it 'does not render a live region' do
        expect(page).not_to have_css(".fr-sr-only[aria-live='polite']", visible: :all)
      end
    end
  end

  context 'with complex markup structure' do
    def check_fieldset_structure(fieldset)
      expect(fieldset[:class]).to include('fr-fieldset')

      # Vérifie que chaque fr-fieldset a un enfant fr-fieldset__element ou une légende
      fieldset.all('> *').each do |child|
        expect(child.tag_name).to be_in(['div', 'legend', 'input'])

        case child.tag_name
        when 'legend'
          expect(child[:class]).to include('fr-fieldset__legend')
        when 'input'
          expect(child[:type]).to eq("hidden")
        else
          expect(child[:class]).to include('fr-fieldset__element')
          # Vérifie récursivement les fieldsets imbriqués
          child.all('> fieldset').each do |nested_fieldset|
            check_fieldset_structure(nested_fieldset)
          end
        end
      end
    end

    let(:types_de_champ_public) {
      [
        { type: :header_section, level: 1 },
        { type: :header_section, level: 2 },
        { type: :header_section, level: 3 },
        { type: :integer_number },

        { type: :header_section, level: 3 },
        { type: :yes_no },

        { type: :header_section, level: 2 },
        { type: :header_section, level: 3 },
        { type: :integer_number },

        { type: :header_section, level: 1 },
        { type: :text },
        { type: :header_section, level: 2 },
        { type: :text },
      ]
    }

    it 'respect dsfr fieldset hierarchy' do
      within('.dossier-edit .form') do
        all('fieldset').each do |fieldset|
          check_fieldset_structure(fieldset)
        end
      end
    end
  end
end
