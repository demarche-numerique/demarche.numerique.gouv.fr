# frozen_string_literal: true

describe TypesDeChampEditor::DossierLinkChampComponent, type: :component do
  describe 'render' do
    let(:procedure) { create(:procedure) }
    let(:procedures) do
      [
        create(:procedure, libelle: "Procedure 1", aasm_state: "publiee"),
        create(:procedure, libelle: "Procedure 2", aasm_state: "brouillon"),
        create(:procedure, libelle: "Procedure 3", aasm_state: "close"),
        create(:procedure, libelle: "Procedure 4", aasm_state: "depubliee"),
      ]
    end
    let(:type_de_champ) { build(:type_de_champ_dossier_link) }
    let(:form) { instance_double('Form') }
    subject { described_class.new(procedures: procedures, type_de_champ: type_de_champ, form: form, procedure: procedure) }

    before do
      allow(form).to receive(:field_name).and_return("")
    end

    describe '#react_props' do
      it 'returns the correct props' do
        props = subject.react_props

        expect(props[:id]).to eq("procedures_type_de_champ")
        expect(props[:label]).to eq("Sélectionnez la ou les démarches concernées")
        expect(props[:selected_keys]).to eq([])
        expect(props[:'aria-label']).to eq("Liste des démarches")
        expect(props[:sections].map { it[:label] }).to contain_exactly('Démarches publiées', 'Démarches en test', 'Démarches closes/dépubliées')
      end
    end

    describe '#sections' do
      it 'groups procedures by state' do
        sections = subject.sections
        sections_by_label = sections.index_by { it[:label] }

        expect(sections_by_label['Démarches publiées'][:items].size).to eq(1)
        expect(sections_by_label['Démarches en test'][:items].size).to eq(1)
        expect(sections_by_label['Démarches closes/dépubliées'][:items].size).to eq(2)
      end
    end

    context 'with no selected procedure ids' do
      let(:type_de_champ) { build(:type_de_champ_dossier_link, options: { dossier_link_procedure_ids: [] }) }

      it 'returns an empty selected_keys' do
        expect(subject.react_props[:selected_keys]).to eq([])
      end
    end

    context 'with multiple selected procedure ids' do
      let(:type_de_champ) { build(:type_de_champ_dossier_link, options: { dossier_link_procedure_ids: procedures.map { it.id.to_s } }) }

      it 'returns the correct selected_keys' do
        expect(subject.react_props[:selected_keys]).to eq(procedures.map { it.id.to_s })
      end
    end
  end
end
