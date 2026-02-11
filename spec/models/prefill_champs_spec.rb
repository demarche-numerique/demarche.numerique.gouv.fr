# frozen_string_literal: true

RSpec.describe PrefillChamps do
  describe "#to_a", vcr: { cassette_name: 'api_geo_all' } do
    let(:procedure) { create(:procedure, :published, types_de_champ_public:, types_de_champ_private:) }
    let(:dossier) { create(:dossier, :brouillon, procedure:) }
    let(:linked_dossier) { create(:dossier, :en_construction, procedure:) }
    let(:types_de_champ_public) { [] }
    let(:types_de_champ_private) { [] }

    subject(:prefill_champs_array) { described_class.new(dossier, params).to_a }

    context "when the stable ids match the TypeDeChamp of the corresponding procedure" do
      let(:types_de_champ_public) { [{ type: :text }, { type: :textarea }] }
      let(:type_de_champ_1) { procedure.published_revision.types_de_champ_public.first }
      let(:value_1) { "any value" }
      let(:champ_id_1) { find_champ_by_stable_id(dossier, type_de_champ_1.stable_id).id }

      let(:type_de_champ_2) { procedure.published_revision.types_de_champ_public.second }
      let(:value_2) { "another value" }
      let(:champ_id_2) { find_champ_by_stable_id(dossier, type_de_champ_2.stable_id).id }

      let(:params) {
        {
          "champ_#{type_de_champ_1.to_typed_id_for_query}" => value_1,
          "champ_#{type_de_champ_2.to_typed_id_for_query}" => value_2,
        }
      }

      it "builds an array of hash(id, value) matching all the given params" do
        expect(prefill_champs_array).to match_array([
          { id: champ_id_1, value: value_1 },
          { id: champ_id_2, value: value_2 },
        ])
      end
    end

    context "when the typed id is not prefixed by 'champ_'" do
      let(:type_de_champ) { procedure.published_revision.types_de_champ_public.first }
      let(:types_de_champ_public) { [{ type: :text }] }

      let(:params) { { type_de_champ.to_typed_id_for_query => "value" } }

      it "filters out the champ" do
        expect(prefill_champs_array).to match([])
      end
    end

    context "when the typed id is unknown" do
      let(:params) { { "champ_jane_doe" => "value" } }

      it "filters out the unknown params" do
        expect(prefill_champs_array).to match([])
      end
    end

    context 'when there is no Champ that matches the TypeDeChamp with the given stable id' do
      let!(:type_de_champ) { create(:type_de_champ_text) } # goes to another procedure

      let(:params) { { "champ_#{type_de_champ.to_typed_id_for_query}" => "value" } }

      it "filters out the param" do
        expect(prefill_champs_array).to match([])
      end
    end

    context "when the public type de champ is authorized" do
      let_it_be(:procedure) do
        ref = create(:api_referentiel, :exact_match)
        create(:procedure, :published, types_de_champ_public: [
          { type: :text }, { type: :textarea }, { type: :decimal_number },
          { type: :integer_number }, { type: :email }, { type: :phone },
          { type: :iban }, { type: :civilite }, { type: :pays },
          { type: :regions }, { type: :date }, { type: :datetime },
          { type: :yes_no }, { type: :checkbox }, { type: :drop_down_list },
          { type: :departements }, { type: :communes }, { type: :address },
          { type: :multiple_drop_down_list }, { type: :dossier_link },
          { type: :epci }, { type: :siret },
          { type: :referentiel, referentiel: ref }
        ])
      end
      let_it_be(:dossier, reload: true) { create(:dossier, :brouillon, procedure:) }
      let_it_be(:linked_dossier) { create(:dossier, :en_construction, procedure:) }

      [
        [:text, "value"],
        [:textarea, "value"],
        [:decimal_number, "3.14"],
        [:integer_number, "42"],
        [:email, "value"],
        [:phone, "value"],
        [:iban, "value"],
        [:civilite, "M."],
        [:pays, "FR"],
        [:regions, "03"],
        [:date, "2022-12-22"],
        [:datetime, "2022-12-22T10:30"],
        [:yes_no, "true"],
        [:yes_no, "false"],
        [:checkbox, "true"],
        [:checkbox, "false"],
        [:drop_down_list, "value"],
        [:departements, "03"],
        [:communes, ['01540', '01457']],
        [:address, "20 avenue de Ségur 75007 Paris"],
        [:multiple_drop_down_list, ["val1", "val2"]],
        [:dossier_link, :linked_dossier_id],
        [:epci, ['01', '200042935']],
        [:siret, "13002526500013"],
        [:referentiel, "13002526500013"]
      ].each do |type, value|
        it "builds correct prefill for #{type} (#{value})", :slow do
          tdc = procedure.published_revision.types_de_champ_public.find { _1.type_champ == type.to_s }
          champ = find_champ_by_stable_id(dossier, tdc.stable_id)
          champ_value = value == :linked_dossier_id ? linked_dossier.id : value
          params = { "champ_#{tdc.to_typed_id_for_query}" => champ_value }
          result = described_class.new(dossier, params).to_a
          expect(result).to match([{ id: champ.id }.merge(attributes(champ, champ_value))])
        end
      end
    end

    context "when the public type de champ is authorized (repetition)" do
      let(:types_de_champ_public) { [{ type: :repetition, children: [{ type: :text }] }] }
      let(:type_de_champ) { procedure.published_revision.types_de_champ_public.first }
      let(:type_de_champ_child) { procedure.published_revision.children_of(type_de_champ).first }
      let(:type_de_champ_child_value) { "value" }
      let(:type_de_champ_child_value2) { "value2" }
      let(:child_champs) { dossier.champs.where(stable_id: type_de_champ_child.stable_id) }

      let(:params) { { "champ_#{type_de_champ.to_typed_id_for_query}" => [{ "champ_#{type_de_champ_child.to_typed_id_for_query}" => type_de_champ_child_value }, { "champ_#{type_de_champ_child.to_typed_id_for_query}" => type_de_champ_child_value2 }] } }

      it "builds an array of hash(id, value) matching the given params" do
        expect(prefill_champs_array).to match([{ id: child_champs.first.id, value: type_de_champ_child_value }, { id: child_champs.second.id, value: type_de_champ_child_value2 }])
      end
    end

    context "when the private type de champ is authorized" do
      let_it_be(:procedure) do
        create(:procedure, :published, types_de_champ_private: [
          { type: :text }, { type: :textarea }, { type: :decimal_number },
          { type: :integer_number }, { type: :email }, { type: :phone },
          { type: :iban }, { type: :civilite }, { type: :pays },
          { type: :regions }, { type: :date }, { type: :datetime },
          { type: :yes_no }, { type: :checkbox }, { type: :drop_down_list },
          { type: :departements }, { type: :communes }, { type: :address },
          { type: :multiple_drop_down_list }, { type: :dossier_link },
          { type: :epci }, { type: :siret }
        ])
      end
      let_it_be(:dossier, reload: true) { create(:dossier, :brouillon, procedure:) }
      let_it_be(:linked_dossier) { create(:dossier, :en_construction, procedure:) }

      [
        [:text, "value"],
        [:textarea, "value"],
        [:decimal_number, "3.14"],
        [:integer_number, "42"],
        [:email, "value"],
        [:phone, "value"],
        [:iban, "value"],
        [:civilite, "M."],
        [:pays, "FR"],
        [:regions, "93"],
        [:date, "2022-12-22"],
        [:datetime, "2022-12-22T10:30"],
        [:yes_no, "true"],
        [:yes_no, "false"],
        [:checkbox, "true"],
        [:checkbox, "false"],
        [:drop_down_list, "value"],
        [:regions, "93"],
        [:siret, "13002526500013"],
        [:departements, "03"],
        [:communes, ['01540', '01457']],
        [:address, "20 avenue de Ségur 75007 Paris"],
        [:multiple_drop_down_list, ["val1", "val2"]],
        [:dossier_link, :linked_dossier_id],
        [:epci, ['01', '200042935']]
      ].each do |type, value|
        it "builds correct prefill for #{type} (#{value})", :slow do
          tdc = procedure.published_revision.types_de_champ_private.find { _1.type_champ == type.to_s }
          champ = find_champ_by_stable_id(dossier, tdc.stable_id)
          champ_value = value == :linked_dossier_id ? linked_dossier.id : value
          params = { "champ_#{tdc.to_typed_id_for_query}" => champ_value }
          result = described_class.new(dossier, params).to_a
          expect(result).to match([{ id: champ.id }.merge(attributes(champ, champ_value))])
        end
      end
    end

    context "when the private type de champ is authorized (repetition)" do
      let(:types_de_champ_private) { [{ type: :repetition, children: [{ type: :text }] }] }
      let(:type_de_champ) { procedure.published_revision.types_de_champ_private.first }
      let(:type_de_champ_child) { procedure.published_revision.children_of(type_de_champ).first }
      let(:type_de_champ_child_value) { "value" }
      let(:type_de_champ_child_value2) { "value2" }
      let(:child_champs) { dossier.champs.where(stable_id: type_de_champ_child.stable_id) }

      let(:params) { { "champ_#{type_de_champ.to_typed_id_for_query}" => [{ "champ_#{type_de_champ_child.to_typed_id_for_query}" => type_de_champ_child_value }, { "champ_#{type_de_champ_child.to_typed_id_for_query}" => type_de_champ_child_value2 }] } }

      it "builds an array of hash(id, value) matching the given params" do
        expect(prefill_champs_array).to match([{ id: child_champs.first.id, value: type_de_champ_child_value }, { id: child_champs.second.id, value: type_de_champ_child_value2 }])
      end
    end

    context "when the public type de champ is unauthorized" do
      let_it_be(:procedure) do
        create(:procedure, :published, types_de_champ_public: [
          { type: :decimal_number }, { type: :integer_number }, { type: :number },
          { type: :dossier_link }, { type: :titre_identite }, { type: :civilite },
          { type: :date }, { type: :linked_drop_down_list }, { type: :header_section },
          { type: :explication }, { type: :piece_justificative }, { type: :cnaf },
          { type: :dgfip }, { type: :pole_emploi }, { type: :mesri },
          { type: :carte }, { type: :pays }, { type: :regions },
          { type: :departements }, { type: :communes }, { type: :multiple_drop_down_list }
        ])
      end
      let_it_be(:dossier, reload: true) { create(:dossier, :brouillon, procedure:) }

      [
        [:decimal_number, "non decimal string"],
        [:integer_number, "non integer string"],
        [:number, "value"],
        [:dossier_link, "value"],
        [:titre_identite, "value"],
        [:civilite, "value"],
        [:date, "value"],
        [:linked_drop_down_list, "value"],
        [:header_section, "value"],
        [:explication, "value"],
        [:piece_justificative, "value"],
        [:cnaf, "value"],
        [:dgfip, "value"],
        [:pole_emploi, "value"],
        [:mesri, "value"],
        [:carte, "value"],
        [:pays, "value"],
        [:regions, "value"],
        [:departements, "value"],
        [:communes, "value"],
        [:multiple_drop_down_list, ["value"]]
      ].each do |type, value|
        it "filters out unauthorized #{type}" do
          tdc = procedure.published_revision.types_de_champ_public.find { _1.type_champ == type.to_s }
          params = { "champ_#{tdc.to_typed_id_for_query}" => value }
          result = described_class.new(dossier, params).to_a
          expect(result).to match([])
        end
      end
    end

    context "when the public type de champ is unauthorized because of wrong value format (repetition)" do
      let(:types_de_champ_public) { [{ type: :repetition, children: [{ type: :text }] }] }
      let(:type_de_champ) { procedure.published_revision.types_de_champ_public.first }
      let(:type_de_champ_child) { procedure.published_revision.children_of(type_de_champ).first }

      let(:params) { { "champ_#{type_de_champ.to_typed_id_for_query}" => "value" } }

      it "builds an array of hash(id, value) matching the given params" do
        expect(prefill_champs_array).to match([])
      end
    end

    context "when the public type de champ is unauthorized because of wrong value typed_id (repetition)" do
      let(:types_de_champ_public) { [{ type: :repetition, children: [{ type: :text }] }] }
      let(:type_de_champ) { procedure.published_revision.types_de_champ_public.first }
      let(:type_de_champ_child) { procedure.published_revision.children_of(type_de_champ).first }

      let(:params) { { "champ_#{type_de_champ.to_typed_id_for_query}" => ["{\"wrong\":\"value\"}", "{\"wrong\":\"value2\"}"] } }

      it "builds an array of hash(id, value) matching the given params" do
        expect(prefill_champs_array).to match([])
      end
    end
  end

  private

  def find_champ_by_stable_id(dossier, stable_id)
    dossier.champs.find_by(stable_id:)
  end

  def attributes(champ, value)
    TypesDeChamp::PrefillTypeDeChamp
      .build(champ.type_de_champ, procedure.active_revision)
      .to_assignable_attributes(champ, value)
  end
end
