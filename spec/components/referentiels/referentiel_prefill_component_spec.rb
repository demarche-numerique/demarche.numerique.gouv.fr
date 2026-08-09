# frozen_string_literal: true

RSpec.describe Referentiels::ReferentielPrefillComponent, type: :component do
  let(:component) { described_class.new(referentiel:, type_de_champ:, procedure:) }
  let(:base_stable_id) { ActiveRecord::Base.connection.select_value("SELECT last_value FROM types_de_champ_id_seq").to_i }
  let(:procedure) { create(:procedure, types_de_champ_public:, types_de_champ_private:) }
  let(:types_de_champ_public) { [{ type: :referentiel, referentiel: }] }
  let(:types_de_champ_private) { [{ type: :text, libelle: "private text" }] }
  let(:type_de_champ) { procedure.draft_revision.types_de_champ.find(&:referentiel?) }
  let(:referentiel) { create(:api_referentiel, :exact_match) }

  subject { render_inline(component) }
  describe 'render' do
    context 'when mapping is blank' do
      it { expect(subject.to_html).to be_empty }
    end

    context 'when mapping is present' do
      let(:referentiel_mapping) do
        {
          "$.jsonpath" => {
            "prefill" => '1',
            'type' => Referentiels::MappingFormComponent::TYPES[:string],
          },
        }
      end

      before { type_de_champ.record.update(referentiel_mapping:) }

      it 'renders the table headers' do
        expect(subject).to have_selector('th', text: 'Propriété')
        expect(subject).to have_selector('th', text: 'Exemple de donnée')
        expect(subject).to have_selector('th', text: 'Type de Donnée')
        expect(subject).to have_selector('th', text: 'Champ du formulaire usager à préremplir')
      end
    end
  end

  describe 'selectable source_tdcs' do
    before { type_de_champ.record.update(referentiel_mapping:) }
    let(:prefill_stable_id) { nil }

    let(:referentiel_mapping) do
      {
        "$.jsonpath" => {
          "prefill" => '1',
          'type' => referentiel_mapping_type,
          'prefill_stable_id' => prefill_stable_id,
        },
      }
    end

    context 'when referentiel is public' do
      context 'with mapping type :string' do
        let(:referentiel_mapping_type) { Referentiels::MappingFormComponent::TYPES[:string] }
        let(:types_de_champ_public) do
          [
            { stable_id: base_stable_id + 100, type: :text, libelle: 'before, not selectable' },
            { type: :referentiel, referentiel: }, # exclu (champ courant)
            { stable_id: base_stable_id + 101, type: :text, libelle: 'text' },
            { stable_id: base_stable_id + 102, type: :textarea, libelle: 'textarea' },
            { stable_id: base_stable_id + 106, type: :yes_no, libelle: 'yes_no' }, # exclu (type non compatible)
            { stable_id: base_stable_id + 107, type: :referentiel, libelle: 'another referentiel' },
          ]
        end

        context 'when not selected' do
          it 'shows public text and textarea as well as private text' do
            expect(subject).to have_select('type_de_champ[referentiel_mapping][$.jsonpath][prefill_stable_id]', options: ['text', 'textarea', 'private text', 'another referentiel'])
            expect(subject).to have_selector('optgroup[label="Champs"]')
            expect(subject).to have_selector('optgroup[label="Annotations privées"]')
          end
        end

        context 'when prefill_stable_id is selected' do
          let(:prefill_stable_id) { base_stable_id + 101 }
          it 'shows the selected prefill_stable_id' do
            expect(subject).to have_select('type_de_champ[referentiel_mapping][$.jsonpath][prefill_stable_id]', selected: ['text'])
          end
        end
      end

      context 'with mapping type :float' do
        let(:referentiel_mapping_type) { Referentiels::MappingFormComponent::TYPES[:decimal_number] }
        let(:types_de_champ_public) do
          [
            { type: :referentiel, referentiel: }, # exclu (champ courant)
            { stable_id: base_stable_id + 101, type: :text, libelle: 'text' }, # exclu (type non compatible)
            { stable_id: base_stable_id + 103, type: :decimal_number, libelle: 'decimal' },
          ]
        end
        it 'shows only decimal_number' do
          expect(subject).to have_select('type_de_champ[referentiel_mapping][$.jsonpath][prefill_stable_id]', options: ['decimal'])
        end
      end

      context 'with mapping type :integer' do
        let(:referentiel_mapping_type) { Referentiels::MappingFormComponent::TYPES[:integer_number] }
        let(:types_de_champ_public) do
          [
            { type: :referentiel, referentiel: }, # exclu (champ courant)
            { stable_id: base_stable_id + 103, type: :decimal_number, libelle: 'decimal' }, # exclu (type non compatible)
            { stable_id: base_stable_id + 104, type: :integer_number, libelle: 'integer' },
            { stable_id: base_stable_id + 107, type: :referentiel, libelle: 'another referentiel' },
          ]
        end
        it 'shows only integer_number' do
          expect(subject).to have_select('type_de_champ[referentiel_mapping][$.jsonpath][prefill_stable_id]', options: ['integer', 'another referentiel'])
        end
      end

      context 'with mapping type :boolean' do
        let(:referentiel_mapping_type) { Referentiels::MappingFormComponent::TYPES[:boolean] }
        let(:types_de_champ_public) do
          [
            { type: :referentiel, referentiel: }, # exclu (champ courant)
            { stable_id: base_stable_id + 101, type: :text, libelle: 'text' }, # exclu (type non compatible)
            { stable_id: base_stable_id + 105, type: :checkbox, libelle: 'checkbox' },
            { stable_id: base_stable_id + 106, type: :yes_no, libelle: 'yes_no' },
          ]
        end
        it 'shows only checkbox and yes_no' do
          expect(subject).to have_select('type_de_champ[referentiel_mapping][$.jsonpath][prefill_stable_id]', options: ['checkbox', 'yes_no'])
        end
      end

      context 'with mapping type :date' do
        let(:referentiel_mapping_type) { Referentiels::MappingFormComponent::TYPES[:date] }
        let(:types_de_champ_public) do
          [
            { type: :referentiel, referentiel: }, # exclu (champ courant)
            { stable_id: base_stable_id + 107, type: :date, libelle: 'date' },
            { stable_id: base_stable_id + 108, type: :text, libelle: 'text' }, # exclu (type non compatible)
          ]
        end
        it 'shows only date' do
          expect(subject).to have_select('type_de_champ[referentiel_mapping][$.jsonpath][prefill_stable_id]', options: ['date'])
        end
      end

      context 'with mapping type :datetime' do
        let(:referentiel_mapping_type) { Referentiels::MappingFormComponent::TYPES[:datetime] }
        let(:types_de_champ_public) do
          [
            { type: :referentiel, referentiel: }, # exclu (champ courant)
            { stable_id: base_stable_id + 109, type: :datetime, libelle: 'datetime' },
            { stable_id: base_stable_id + 108, type: :text, libelle: 'text' }, # exclu (type non compatible)
          ]
        end
        it 'shows only datetime' do
          expect(subject).to have_select('type_de_champ[referentiel_mapping][$.jsonpath][prefill_stable_id]', options: ['datetime'])
        end
      end

      context 'with mapping type :array' do
        let(:referentiel_mapping_type) { Referentiels::MappingFormComponent::TYPES[:array] }
        let(:types_de_champ_public) do
          [
            { type: :referentiel, referentiel: }, # exclu (champ courant)
            { stable_id: base_stable_id + 110, type: :multiple_drop_down_list, libelle: 'multiple' },
            { stable_id: base_stable_id + 108, type: :text, libelle: 'text' }, # exclu (type non compatible)
          ]
        end
        it 'shows only multiple_drop_down_list' do
          expect(subject).to have_select('type_de_champ[referentiel_mapping][$.jsonpath][prefill_stable_id]', options: ['multiple'])
        end
      end
    end

    context 'when referentiel is private' do
      let(:types_de_champ_public) { [{ type: :text, libelle: "public text" }] }
      let(:types_de_champ_private) { [{ type: :referentiel, referentiel: }, { type: :text, libelle: "private text" }] }
      let(:referentiel) { create(:api_referentiel, :exact_match) }
      let(:referentiel_mapping_type) { Referentiels::MappingFormComponent::TYPES[:string] }

      context 'when not selected' do
          it 'shows only private text' do
            expect(subject).to have_select('type_de_champ[referentiel_mapping][$.jsonpath][prefill_stable_id]', options: ['private text'])
            expect(subject).not_to have_selector('optgroup[label="Champs"]')
            expect(subject).not_to have_selector('optgroup[label="Annotations privées"]')
          end
        end
    end
  end

  describe '#source_tdcs' do
    let(:types_de_champ_private) { [] }
    let(:referentiel_mapping_type) { Referentiels::MappingFormComponent::TYPES[:string] }
    subject { component.source_tdcs.map { |tdc| tdc[:libelle] } }

    context 'when referentiel is not in repetition' do
      let(:types_de_champ_public) do
        [
          {
            type: :repetition, libelle: 'la repetition', children: [
              { type: :text, libelle: 'position 0' },
              { type: :text, libelle: 'position 1' },
              { type: :text, libelle: 'position 2' },
              { type: :text, libelle: 'position 3' },
            ],
          },
          { type: :referentiel, referentiel:, libelle: "referentiel" },
          { type: :text, libelle: 'text after referentiel' },
        ]
      end

      it 'ignores childs of repetition with higher position than referentiel' do
        expect(subject).to eq(['text after referentiel'])
      end
    end

    context 'when referentiel is in repetition' do
      let(:types_de_champ_public) do
        [
          { type: :text, libelle: 'before repetition' },
          {
            type: :repetition, libelle: 'la repetition', children: [
              { type: :text, libelle: 'position 0' },
              { type: :referentiel, referentiel:, libelle: "referentiel" },
              { type: :text, libelle: 'position 1' },
              { type: :text, libelle: 'position 2' },
              { type: :text, libelle: 'position 3' },
            ],
          },
          {
            type: :repetition, libelle: 'une autre', children: [
              { type: :text, libelle: 'autre repetition position 0' },
              { type: :text, libelle: 'autre repetition position 1' },
              { type: :text, libelle: 'autre repetition position 2' },
            ],
          },
          { type: :text, libelle: 'after repetition' },

        ]
      end

      it "returns only children of current repetition" do
        expect(subject).to eq(["position 1", "position 2", "position 3"])
      end
    end
  end
end
