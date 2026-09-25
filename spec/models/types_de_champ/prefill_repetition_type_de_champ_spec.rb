# frozen_string_literal: true

RSpec.describe TypesDeChamp::PrefillRepetitionTypeDeChamp, type: :model do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :repetition, children: [{}, { type: :integer_number }, { type: :regions }] }]) }
  let(:dossier) { create(:dossier, procedure: procedure) }
  let(:champ) { dossier.root_champs_public.first }
  let(:type_de_champ) { champ.type_de_champ }
  let(:prefillable_subchamps) { TypesDeChamp::PrefillRepetitionTypeDeChamp.new(type_de_champ, procedure.active_revision).send(:prefillable_subchamps) }
  let(:text_repetition) { prefillable_subchamps.first }
  let(:integer_repetition) { prefillable_subchamps.second }
  let(:region_repetition) { prefillable_subchamps.third }
  let(:text_repetition_champs) { champ.rows.map { it.flat_children.first } }
  let(:integer_repetition_champs) { champ.rows.map { it.flat_children.second } }

  describe 'ancestors' do
    subject { described_class.build(type_de_champ, procedure.active_revision) }

    it { is_expected.to be_kind_of(TypesDeChamp::PrefillTypeDeChamp) }
  end

  describe '#possible_values' do
    subject(:possible_values) { described_class.new(type_de_champ, procedure.active_revision).possible_values }
    let(:expected_value) {
      "Un tableau de dictionnaires avec les valeurs possibles pour chaque champ de la répétition.<br><ul><li>champ_#{text_repetition.to_typed_id_for_query}: Un texte court<br></li><li>champ_#{integer_repetition.to_typed_id_for_query}: Un nombre entier<br></li><li>champ_#{region_repetition.to_typed_id_for_query}: Un <a href=\"https://fr.wikipedia.org/wiki/R%C3%A9gion_fran%C3%A7aise\" target=\"_blank\" rel=\"noopener noreferrer\">code INSEE de région</a><br><a title=\"Toutes les valeurs possibles — Nouvel onglet\" target=\"_blank\" rel=\"noopener\" href=\"/procedures/#{procedure.path}/prefill_type_de_champs/#{region_repetition.id}\">Voir toutes les valeurs possibles</a></li></ul>"
    }

    it {
      expect(possible_values).to eq(expected_value)
    }
  end

  describe '#possible_values does not contain unescaped HTML (XSS prevention)' do
    let(:xss_payload) { '<script>alert("XSS")</script>' }
    let(:procedure_with_dropdown) { create(:procedure, public_type_de_champs: [{ type: :repetition, children: [{ type: :drop_down_list }] }]) }
    let(:repetition_tdc) { procedure_with_dropdown.public_draft_type_de_champs.find(&:repetition?) }

    before do
      sub_tdc = procedure_with_dropdown.active_revision.children_of(repetition_tdc).first
      sub_tdc.update!(drop_down_options: [xss_payload, "safe"])
    end

    subject(:possible_values) { described_class.new(repetition_tdc, procedure_with_dropdown.active_revision).possible_values }

    it 'does not contain raw script tags from sub-champ drop_down_options' do
      expect(possible_values).not_to include('<script>alert("XSS")</script>')
    end
  end

  describe '#example_value' do
    subject(:example_value) { described_class.new(type_de_champ, procedure.active_revision).example_value }
    let(:expected_value) { [{ "champ_#{text_repetition.to_typed_id_for_query}" => "Texte court", "champ_#{integer_repetition.to_typed_id_for_query}" => 42, "champ_#{region_repetition.to_typed_id_for_query}" => "53" }, { "champ_#{text_repetition.to_typed_id_for_query}" => "Texte court", "champ_#{integer_repetition.to_typed_id_for_query}" => 42, "champ_#{region_repetition.to_typed_id_for_query}" => "53" }] }

    it { expect(example_value).to eq(expected_value) }
  end

  # Every type de champ that is both prefillable and allowed inside a repetition.
  # `communes` and `epci` were the ones silently dropped before #10610 was fixed;
  # `multiple_drop_down_list` also has an array example value but escaped the bug
  # because its screening parses a JSON string back into an array. The whole set is
  # covered so that a new type cannot regress unnoticed.
  PREFILLABLE_IN_REPETITION = [
    :address, :checkbox, :civilite, :communes, :date, :datetime, :decimal_number,
    :departements, :drop_down_list, :email, :epci, :formatted, :iban,
    :integer_number, :multiple_drop_down_list, :pays, :phone, :regions, :text,
    :textarea, :yes_no,
  ].freeze

  describe 'prefilling each prefillable type inside a repetition' do
    PREFILLABLE_IN_REPETITION.each do |type_champ|
      context "with a #{type_champ} sub-champ" do
        let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :repetition, children: [{ type: type_champ }] }]) }
        let(:dossier) { create(:dossier, procedure: procedure) }
        let(:repetition_type_de_champ) { procedure.public_draft_type_de_champs.find(&:repetition?) }
        let(:prefill) { described_class.build(repetition_type_de_champ, procedure.active_revision) }
        let(:key) { "champ_#{repetition_type_de_champ.to_typed_id_for_query}" }

        # Both entry points reach the same code with differently shaped values:
        # the link goes through a query string, the API through a JSON body.
        def prefill_with(params)
          dossier.prefill!(PrefillChamps.new(dossier, params).to_a, {})
          dossier.reload.root_champs_public.find(&:repetition?)
        end

        # A champ fetching its data asynchronously (address) is prefilled with an
        # external_id and stays blank until its job runs, so only assert on the
        # value for the synchronous ones.
        def expect_both_rows_prefilled(repetition)
          expect(repetition.row_ids.size).to eq(2)
          subchamps = repetition.rows.flat_map(&:flat_children)
          expect(subchamps.size).to eq(2)
          expect(subchamps).to all(be_prefilled)

          settled, pending = subchamps.partition { !_1.has_async_external_data? }
          expect(settled.map(&:blank?)).to all(be(false))
          expect(pending.map(&:external_id)).to all(be_present)
        end

        it 'prefills every row from the generated prefill link' do
          # exactly what the server receives back for the link we hand out
          params = Rack::Utils.parse_nested_query({ key => prefill.example_value_for_query }.to_query)

          expect_both_rows_prefilled(prefill_with(params))
        end

        it 'prefills every row from the API body' do
          expect_both_rows_prefilled(prefill_with({ key => prefill.example_value }))
        end
      end
    end
  end

  describe '#to_assignable_attributes' do
    subject(:to_assignable_attributes) { described_class.build(type_de_champ, procedure.active_revision).to_assignable_attributes(champ, value) }

    context 'when the value is nil' do
      let(:value) { nil }
      it { is_expected.to match([]) }
    end

    context 'when the value is empty' do
      let(:value) { '' }
      it { is_expected.to match([]) }
    end

    context 'when the value is a string' do
      let(:value) { 'hello' }
      it { is_expected.to match([]) }
    end

    context 'when the value is an array with wrong keys' do
      let(:value) { ["{\"blabla\":\"value\"}", "{\"blabla\":\"value2\"}"] }

      it { is_expected.to match([]) }
    end

    context 'when the value is an array with some wrong keys' do
      let(:value) { [{ "champ_#{text_repetition.to_typed_id_for_query}" => "value", "blabla" => "value2" }, { "champ_#{integer_repetition.to_typed_id_for_query}" => "42" }, { "blabla" => "false" }] }

      it { is_expected.to match([[text_repetition_champs.first, { value: "value" }], [integer_repetition_champs.second, { value: "42" }]]) }
    end

    context 'when a subchamp value fails its type screening' do
      let(:value) { [{ "champ_#{integer_repetition.to_typed_id_for_query}" => "not a number" }] }

      it { is_expected.to match([]) }
    end

    # A prefill link indexes its rows, so they come back as a hash keyed by
    # position rather than as an array. Links generated before that change used
    # bare brackets and still arrive as an array, hence both shapes are accepted.
    context 'when the rows are indexed, as a prefill link sends them' do
      let(:value) do
        {
          "0" => { "champ_#{text_repetition.to_typed_id_for_query}" => "first" },
          "1" => { "champ_#{text_repetition.to_typed_id_for_query}" => "second" },
        }
      end

      it 'keeps the rows in index order' do
        expect(to_assignable_attributes).to match([
          [text_repetition_champs.first, { value: "first" }],
          [text_repetition_champs.second, { value: "second" }],
        ])
      end
    end

    context 'when the indexed rows arrive out of order' do
      let(:value) do
        {
          "1" => { "champ_#{text_repetition.to_typed_id_for_query}" => "second" },
          "0" => { "champ_#{text_repetition.to_typed_id_for_query}" => "first" },
        }
      end

      it 'sorts them by index' do
        expect(to_assignable_attributes.map(&:last)).to eq([{ value: "first" }, { value: "second" }])
      end
    end

    context 'when a hash is not keyed by index' do
      let(:value) { { "champ_#{text_repetition.to_typed_id_for_query}" => "not a row" } }

      it { is_expected.to match([]) }
    end

    context 'when the value is an array with right keys' do
      let(:value) { [{ "champ_#{text_repetition.to_typed_id_for_query}" => "value" }, { "champ_#{text_repetition.to_typed_id_for_query}" => "value2" }] }

      it { is_expected.to match([[text_repetition_champs.first, { value: "value" }], [text_repetition_champs.second, { value: "value2" }]]) }
    end
  end
end
