# frozen_string_literal: true

RSpec.describe PrefillChamps do
  describe "#to_a", vcr: { cassette_name: 'api_geo_all' } do
    let(:procedure) { create(:procedure, :published, public_type_de_champs:, private_type_de_champs:) }
    let(:dossier) { create(:dossier, :brouillon, procedure:) }
    let(:linked_dossier) { create(:dossier, :en_construction, procedure:) }
    let(:public_type_de_champs) { [] }
    let(:private_type_de_champs) { [] }

    subject(:prefill_champs_array) { described_class.new(dossier, params).to_a }

    context "when the stable ids match the TypeDeChamp of the corresponding procedure" do
      let(:public_type_de_champs) { [{ type: :text }, { type: :textarea }] }
      let(:type_de_champ_1) { procedure.published_revision.public_root_type_de_champs.first }
      let(:value_1) { "any value" }
      let(:champ_1) { find_champ_by_stable_id(dossier, type_de_champ_1.stable_id) }

      let(:type_de_champ_2) { procedure.published_revision.public_root_type_de_champs.second }
      let(:value_2) { "another value" }
      let(:champ_2) { find_champ_by_stable_id(dossier, type_de_champ_2.stable_id) }

      let(:params) {
        {
          "champ_#{type_de_champ_1.to_typed_id_for_query}" => value_1,
          "champ_#{type_de_champ_2.to_typed_id_for_query}" => value_2,
        }
      }

      it "builds an array of [champ, attributes] pairs matching all the given params" do
        expect(prefill_champs_array).to match_array([
          [champ_1, { value: value_1 }],
          [champ_2, { value: value_2 }],
        ])
      end
    end

    context "when the typed id is not prefixed by 'champ_'" do
      let(:type_de_champ) { procedure.published_revision.public_root_type_de_champs.first }
      let(:public_type_de_champs) { [{ type: :text }] }

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

    shared_examples "a champ public value that is authorized" do |type_de_champ_type, value|
      context "when the type de champ is authorized (#{type_de_champ_type})" do
        let(:public_type_de_champs) { [{ type: type_de_champ_type }.merge(additional_tdc_opts)] }

        let(:additional_tdc_opts) do
          case type_de_champ_type
          when :referentiel
            { referentiel: create(:api_referentiel, :exact_match) }
          when :pre_rempli
            { drop_down_options: ["opt1", "opt2", "opt3"] }
          else
            {}
          end
        end

        let(:type_de_champ) { procedure.published_revision.public_root_type_de_champs.first }
        let(:champ) { find_champ_by_stable_id(dossier, type_de_champ.stable_id) }
        let(:champ_value) { value == 'linked_dossier_id' ? linked_dossier.id : value }

        let(:params) { { "champ_#{type_de_champ.to_typed_id_for_query}" => champ_value } }

        it "builds an array of [champ, attributes] pairs matching the given params", :slow do
          expect(prefill_champs_array).to match([[champ, attributes(champ, champ_value)]])
        end
      end
    end

    shared_examples "a champ private value that is authorized" do |type_de_champ_type, value|
      context "when the type de champ is authorized (#{type_de_champ_type})" do
        let(:private_type_de_champs) { [{ type: type_de_champ_type }.merge(additional_tdc_opts)] }

        let(:additional_tdc_opts) do
          case type_de_champ_type
          when :pre_rempli
            { drop_down_options: ["opt1", "opt2", "opt3"] }
          else
            {}
          end
        end

        let(:type_de_champ) { procedure.published_revision.private_root_type_de_champs.first }
        let(:champ) { find_champ_by_stable_id(dossier, type_de_champ.stable_id) }
        let(:champ_value) { value == 'linked_dossier_id' ? linked_dossier.id : value }

        let(:params) { { "champ_#{type_de_champ.to_typed_id_for_query}" => champ_value } }

        it "builds an array of [champ, attributes] pairs matching the given params", :slow do
          expect(prefill_champs_array).to match([[champ, attributes(champ, champ_value)]])
        end
      end
    end

    shared_examples "a champ public value that is unauthorized" do |type_de_champ_type, value|
      let(:public_type_de_champs) { [{ type: type_de_champ_type }] }
      let(:type_de_champ) { procedure.published_revision.public_root_type_de_champs.first }

      let(:params) { { "champ_#{type_de_champ.to_typed_id_for_query}" => value } }

      context "when the type de champ is unauthorized (#{type_de_champ_type})" do
        it "filters out the param" do
          expect(prefill_champs_array).to match([])
        end
      end
    end

    it_behaves_like "a champ public value that is authorized", :text, "value"
    it_behaves_like "a champ public value that is authorized", :textarea, "value"
    it_behaves_like "a champ public value that is authorized", :decimal_number, "3.14"
    it_behaves_like "a champ public value that is authorized", :integer_number, "42"
    it_behaves_like "a champ public value that is authorized", :email, "value"
    it_behaves_like "a champ public value that is authorized", :phone, "value"
    it_behaves_like "a champ public value that is authorized", :iban, "value"
    it_behaves_like "a champ public value that is authorized", :civilite, "M."
    it_behaves_like "a champ public value that is authorized", :pays, "FR"
    it_behaves_like "a champ public value that is authorized", :regions, "03"
    it_behaves_like "a champ public value that is authorized", :date, "2022-12-22"
    it_behaves_like "a champ public value that is authorized", :datetime, "2022-12-22T10:30"
    it_behaves_like "a champ public value that is authorized", :yes_no, "true"
    it_behaves_like "a champ public value that is authorized", :yes_no, "false"
    it_behaves_like "a champ public value that is authorized", :checkbox, "true"
    it_behaves_like "a champ public value that is authorized", :checkbox, "false"
    it_behaves_like "a champ public value that is authorized", :drop_down_list, "val1"
    it_behaves_like "a champ public value that is authorized", :departements, "03"
    it_behaves_like "a champ public value that is authorized", :communes, ['01540', '01457']
    it_behaves_like "a champ public value that is authorized", :address, "20 avenue de Ségur 75007 Paris"
    it_behaves_like "a champ public value that is authorized", :multiple_drop_down_list, ["val1", "val2"]
    it_behaves_like "a champ public value that is authorized", :dossier_link, 'linked_dossier_id'
    it_behaves_like "a champ public value that is authorized", :epci, ['01', '200042935']
    it_behaves_like "a champ public value that is authorized", :siret, "13002526500013"
    it_behaves_like "a champ public value that is authorized", :referentiel, "13002526500013"
    it_behaves_like "a champ public value that is authorized", :pre_rempli, "opt1"

    context "when the public type de champ is authorized (repetition)" do
      let(:public_type_de_champs) { [{ type: :repetition, children: [{ type: :text }] }] }
      let(:type_de_champ) { procedure.published_revision.public_root_type_de_champs.first }
      let(:type_de_champ_child) { procedure.published_revision.children_of(type_de_champ).first }
      let(:type_de_champ_child_value) { "value" }
      let(:type_de_champ_child_value2) { "value2" }
      let(:child_champs) { dossier.champ_data.where(stable_id: type_de_champ_child.stable_id) }

      let(:params) { { "champ_#{type_de_champ.to_typed_id_for_query}" => [{ "champ_#{type_de_champ_child.to_typed_id_for_query}" => type_de_champ_child_value }, { "champ_#{type_de_champ_child.to_typed_id_for_query}" => type_de_champ_child_value2 }] } }

      it "builds an array of [champ, attributes] pairs matching the given params" do
        expect(prefill_champs_array).to match([[child_champs.first, { value: type_de_champ_child_value }], [child_champs.second, { value: type_de_champ_child_value2 }]])
      end
    end

    it_behaves_like "a champ private value that is authorized", :text, "value"
    it_behaves_like "a champ private value that is authorized", :textarea, "value"
    it_behaves_like "a champ private value that is authorized", :decimal_number, "3.14"
    it_behaves_like "a champ private value that is authorized", :integer_number, "42"
    it_behaves_like "a champ private value that is authorized", :email, "value"
    it_behaves_like "a champ private value that is authorized", :phone, "value"
    it_behaves_like "a champ private value that is authorized", :iban, "value"
    it_behaves_like "a champ private value that is authorized", :civilite, "M."
    it_behaves_like "a champ private value that is authorized", :pays, "FR"
    it_behaves_like "a champ private value that is authorized", :regions, "93"
    it_behaves_like "a champ private value that is authorized", :date, "2022-12-22"
    it_behaves_like "a champ private value that is authorized", :datetime, "2022-12-22T10:30"
    it_behaves_like "a champ private value that is authorized", :yes_no, "true"
    it_behaves_like "a champ private value that is authorized", :yes_no, "false"
    it_behaves_like "a champ private value that is authorized", :checkbox, "true"
    it_behaves_like "a champ private value that is authorized", :checkbox, "false"
    it_behaves_like "a champ private value that is authorized", :drop_down_list, "val1"
    it_behaves_like "a champ private value that is authorized", :regions, "93"
    it_behaves_like "a champ private value that is authorized", :siret, "13002526500013"
    it_behaves_like "a champ private value that is authorized", :departements, "03"
    it_behaves_like "a champ private value that is authorized", :communes, ['01540', '01457']
    it_behaves_like "a champ private value that is authorized", :address, "20 avenue de Ségur 75007 Paris"
    it_behaves_like "a champ private value that is authorized", :multiple_drop_down_list, ["val1", "val2"]
    it_behaves_like "a champ private value that is authorized", :dossier_link, 'linked_dossier_id'
    it_behaves_like "a champ private value that is authorized", :epci, ['01', '200042935']
    it_behaves_like "a champ private value that is authorized", :pre_rempli, "opt1"

    context "when the private type de champ is authorized (repetition)" do
      let(:private_type_de_champs) { [{ type: :repetition, children: [{ type: :text }] }] }
      let(:type_de_champ) { procedure.published_revision.private_root_type_de_champs.first }
      let(:type_de_champ_child) { procedure.published_revision.children_of(type_de_champ).first }
      let(:type_de_champ_child_value) { "value" }
      let(:type_de_champ_child_value2) { "value2" }
      let(:child_champs) { dossier.champ_data.where(stable_id: type_de_champ_child.stable_id) }

      let(:params) { { "champ_#{type_de_champ.to_typed_id_for_query}" => [{ "champ_#{type_de_champ_child.to_typed_id_for_query}" => type_de_champ_child_value }, { "champ_#{type_de_champ_child.to_typed_id_for_query}" => type_de_champ_child_value2 }] } }

      it "builds an array of [champ, attributes] pairs matching the given params" do
        expect(prefill_champs_array).to match([[child_champs.first, { value: type_de_champ_child_value }], [child_champs.second, { value: type_de_champ_child_value2 }]])
      end
    end

    it_behaves_like "a champ public value that is unauthorized", :decimal_number, "non decimal string"
    it_behaves_like "a champ public value that is unauthorized", :integer_number, "non integer string"
    it_behaves_like "a champ public value that is unauthorized", :number, "value"
    it_behaves_like "a champ public value that is unauthorized", :dossier_link, "value"
    it_behaves_like "a champ public value that is unauthorized", :civilite, "value"
    it_behaves_like "a champ public value that is unauthorized", :date, "value"
    it_behaves_like "a champ public value that is unauthorized", :datetime, "value"
    it_behaves_like "a champ public value that is unauthorized", :datetime, "12-22-2022T10:30"
    it_behaves_like "a champ public value that is unauthorized", :linked_drop_down_list, "value"
    it_behaves_like "a champ public value that is unauthorized", :header_section, "value"
    it_behaves_like "a champ public value that is unauthorized", :explication, "value"
    it_behaves_like "a champ public value that is unauthorized", :piece_justificative, "value"
    it_behaves_like "a champ public value that is unauthorized", :carte, "value"
    it_behaves_like "a champ public value that is unauthorized", :pays, "value"
    it_behaves_like "a champ public value that is unauthorized", :regions, "value"
    it_behaves_like "a champ public value that is unauthorized", :departements, "value"
    it_behaves_like "a champ public value that is unauthorized", :communes, "value"
    it_behaves_like "a champ public value that is unauthorized", :multiple_drop_down_list, ["value"]

    context "when the public type de champ is unauthorized because of wrong value format (repetition)" do
      let(:public_type_de_champs) { [{ type: :repetition, children: [{ type: :text }] }] }
      let(:type_de_champ) { procedure.published_revision.public_root_type_de_champs.first }
      let(:type_de_champ_child) { procedure.published_revision.children_of(type_de_champ).first }

      let(:params) { { "champ_#{type_de_champ.to_typed_id_for_query}" => "value" } }

      it "builds an array of hash(id, value) matching the given params" do
        expect(prefill_champs_array).to match([])
      end
    end

    context "when the public type de champ is unauthorized because of wrong value typed_id (repetition)" do
      let(:public_type_de_champs) { [{ type: :repetition, children: [{ type: :text }] }] }
      let(:type_de_champ) { procedure.published_revision.public_root_type_de_champs.first }
      let(:type_de_champ_child) { procedure.published_revision.children_of(type_de_champ).first }

      let(:params) { { "champ_#{type_de_champ.to_typed_id_for_query}" => ["{\"wrong\":\"value\"}", "{\"wrong\":\"value2\"}"] } }

      it "builds an array of hash(id, value) matching the given params" do
        expect(prefill_champs_array).to match([])
      end
    end

    context "when the value is a Hash (malicious input)" do
      let(:public_type_de_champs) { [{ type: :text }] }
      let(:type_de_champ) { procedure.published_revision.public_root_type_de_champs.first }

      let(:params) { { "champ_#{type_de_champ.to_typed_id_for_query}" => { "injected" => "x" } } }

      it "rejects the non-string value" do
        expect(prefill_champs_array).to match([])
      end
    end

    context "when the value is an Array containing a Hash on a simple type" do
      let(:public_type_de_champs) { [{ type: :text }] }
      let(:type_de_champ) { procedure.published_revision.public_root_type_de_champs.first }

      let(:params) { { "champ_#{type_de_champ.to_typed_id_for_query}" => [{ "injected" => "x" }] } }

      it "rejects the non-string value" do
        expect(prefill_champs_array).to match([])
      end
    end

    context "when the address value is a Hash (malicious input)" do
      let(:public_type_de_champs) { [{ type: :address }] }
      let(:type_de_champ) { procedure.published_revision.public_root_type_de_champs.first }

      let(:params) { { "champ_#{type_de_champ.to_typed_id_for_query}" => { "injected" => "x" } } }

      it "rejects the non-string value" do
        expect(prefill_champs_array).to match([])
      end
    end

    context "when the siret value is a Hash (malicious input)" do
      let(:public_type_de_champs) { [{ type: :siret }] }
      let(:type_de_champ) { procedure.published_revision.public_root_type_de_champs.first }

      let(:params) { { "champ_#{type_de_champ.to_typed_id_for_query}" => { "injected" => "x" } } }

      it "does not set external_id to a hash" do
        expect(prefill_champs_array).to match([])
      end
    end
  end

  private

  def find_champ_by_stable_id(dossier, stable_id)
    dossier.champ_data.find_by(stable_id:)
  end

  def attributes(champ, value)
    TypesDeChamp::Prefill
      .build(champ.type_de_champ, procedure.active_revision)
      .to_assignable_attributes(champ, value)
  end
end
