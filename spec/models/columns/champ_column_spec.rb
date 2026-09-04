# frozen_string_literal: true

describe Columns::ChampColumn do
  describe '#value' do
    let_it_be(:procedure) { create(:procedure, :with_all_champs_mandatory) }

    context 'without any cast' do
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:type_de_champs) { procedure.all_revisions_type_de_champs }

      it 'extracts values for columns and type de champ', :slow do
        expect_type_de_champ_values('civilite', eq(["M."]))
        expect_type_de_champ_values('email', eq(['yoda@beta.gouv.fr']))
        expect_type_de_champ_values('phone', eq(['0666666666']))
        expect_type_de_champ_values('address', eq(["2 rue des Démarches grenoble (38100)", "38000", "grenoble", "38", "84", "Auvergne-Rhones-Alpes"]))
        expect_type_de_champ_values('communes', eq(["60580", "Coye-la-Forêt", "60", "32", "Coye-la-Forêt", "60580", "60"]))
        expect_type_de_champ_values('departements', eq(["01", "84", "01"]))
        expect_type_de_champ_values('regions', eq(['01', '01']))
        expect_type_de_champ_values('pays', eq(['FR']))
        expect_type_de_champ_values('epci', eq([nil, nil, nil]))
        expect_type_de_champ_values('iban', eq([nil]))
        expect_type_de_champ_values('siret', match_array(
          [
            "11",
            "44011762001530",
            "SA à conseil d’administration (s.a.i.)",
            "440117620",
            "GRTGAZ",
            "GRTGAZ",
            "1990-04-24",
            "Transports par conduites",
            nil,
            "92270",
            "Bois-Colombes",
            "92",
            "Île-de-France",
          ]
        ))
        expect_type_de_champ_values('text', eq(['text']))
        expect_type_de_champ_values('textarea', eq(['textarea']))
        expect_type_de_champ_values('number', eq(['42']))
        expect_type_de_champ_values('decimal_number', eq([42.1]))
        expect_type_de_champ_values('integer_number', eq([42]))
        expect_type_de_champ_values('date', eq([Time.zone.parse('2019-07-10').to_date]))
        expect_type_de_champ_values('datetime', eq([Time.zone.parse("1962-09-15T15:35:00+01:00")]))
        expect_type_de_champ_values('checkbox', eq([true]))
        expect_type_de_champ_values('drop_down_list', eq(['val1']))
        expect_type_de_champ_values('multiple_drop_down_list', eq([["val1", "val2"]]))
        expect_type_de_champ_values('linked_drop_down_list', eq(["primary / secondary", "primary", "secondary"]))
        expect_type_de_champ_values('yes_no', eq([true]))
        expect_type_de_champ_values('annuaire_education', eq([nil]))
        expect_type_de_champ_values('piece_justificative', be_an_instance_of(Array))
        type_de_champ = type_de_champs.find { it.piece_justificative? && it.titre_identite? }
        champ = dossier.send(:filled_champ, type_de_champ)
        columns = type_de_champ.columns(procedure_id: procedure.id)
        expect(columns.map { _1.value(champ) }).to be_an_instance_of(Array)
        expect_type_de_champ_values('cojo', eq([nil]))
        expect_type_de_champ_values('formatted', eq([nil]))
        expect_type_de_champ_values('rna', eq(["W173847273", "postal_code", "city_name", "department_code", "region_code", "region_name", nil, nil, nil, nil, nil, nil, "LA PRÉVENTION ROUTIERE"]))
        expect_type_de_champ_values('rnf', eq(["075-FDD-00003-01", "postal_code", "city_name", "department_code", "region_code", "region_name", "Fondation SFR"]))
      end
    end

    context 'with cast' do
      def column(label) = procedure.find_column(label:)

      context 'from a text' do
        let(:champ) { Champs::TextChamp.new(value: 'hello') }

        it do
          expect(column('formatted').value(champ)).to eq('hello')
          expect(column('textarea').value(champ)).to eq('hello')
        end
      end

      context 'from a formatted' do
        let(:champ) { Champs::FormattedChamp.new(value: 'hello') }

        it do
          expect(column('text').value(champ)).to eq('hello')
          expect(column('textarea').value(champ)).to eq('hello')
        end
      end

      context 'from a integer_number' do
        let(:champ) { Champs::IntegerNumberChamp.new(value: '42') }

        it do
          expect(column('decimal_number').value(champ)).to eq(42.0)
          expect(column('text').value(champ)).to eq('42')
        end
      end

      context 'from a decimal_number' do
        let(:champ) { Champs::DecimalNumberChamp.new(value: '42.1') }

        it do
          expect(column('integer_number').value(champ)).to eq(42)
          expect(column('text').value(champ)).to eq('42.1')
        end
      end

      context 'from a date' do
        let(:champ) { Champs::DateChamp.new(value:) }

        describe 'when the value is valid' do
          let(:value) { '2019-07-10' }

          it { expect(column('datetime').value(champ)).to eq(Time.zone.parse('2019-07-10')) }
        end

        describe 'when the value is invalid' do
          let(:value) { 'invalid' }

          it { expect(column('datetime').value(champ)).to be_nil }
        end
      end

      context 'from a datetime' do
        let(:champ) { Champs::DatetimeChamp.new(value:) }

        describe 'when the value is valid' do
          let(:value) { '1962-09-15T15:35:00+01:00' }

          it { expect(column('date').value(champ)).to eq('1962-09-15'.to_date) }
        end

        describe 'when the value is invalid' do
          let(:value) { 'invalid' }

          it { expect(column('date').value(champ)).to be_nil }
        end
      end

      context 'from a drop_down_list' do
        let(:champ) { Champs::DropDownListChamp.new(value:) }
        let(:value) { 'val1' }

        it do
          expect(column('multiple_drop_down_list').value(champ)).to eq(['val1'])
          expect(column('text').value(champ)).to eq('val1')
        end
      end

      context 'from a multiple_drop_down_list' do
        let(:champ) { Champs::MultipleDropDownListChamp.new(value:) }
        let(:value) { '["val1","val2"]' }

        it do
          expect(column('simple_drop_down_list').value(champ)).to eq('val1')
          expect(column('text').value(champ)).to eq('val1, val2')
          expect(column('formatted').value(champ)).to eq('val1, val2')
          expect(column('textarea').value(champ)).to eq("val1\nval2")
        end
      end

      context 'from a communes' do
        let(:champ) do
          Champs::CommuneChamp.new(
            value: 'Coye-la-Forêt',
            external_id: '60172',
            code_postal: '60580'
          )
        end

        it do
          expect(column('text').value(champ)).to eq('Coye-la-Forêt')
          expect(column('textarea').value(champ)).to eq('Coye-la-Forêt')
          expect(column('formatted').value(champ)).to eq('Coye-la-Forêt')
        end
      end
    end
  end

  describe '#filtered_ids' do
    subject { column.filtered_ids(dossiers, { operator: 'match', value: search_terms }) }

    context "with a text champ" do
      let_it_be(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text, mandatory: false, libelle: "text" }]) }
      let(:dossier_with_value) { create(:dossier, :en_instruction, procedure:) }

      let(:column) { procedure.find_column(label: "text") }
      let(:dossiers) { procedure.dossiers }

      before do
        dossier_with_value.champ_data.first.update!(value: champ_value)
      end

      let(:champ_value) { 'olala le text est "là"' }

      context "when searching for a basic value" do
        let(:search_terms) { ["olala"] }

        it "returns the correct ids" do
          expect(subject).to match_array([dossier_with_value.id])
        end
      end

      context "when searching for a value with quotes" do
        let(:search_terms) { ['"là"'] }
        it "returns the correct ids" do
          expect(subject).to match_array([dossier_with_value.id])
        end
      end
    end

    context "with a multiple_drop_down_list champ" do
      let_it_be(:procedure) { create(:procedure, public_type_de_champs: [{ type: :multiple_drop_down_list, mandatory: false, libelle: "multiple_drop_down_list", options: ["Fromage", 'Fromage "blanc"'] }]) }
      let(:dossier_with_value) { create(:dossier, :en_instruction, procedure:) }

      let(:column) { procedure.find_column(label: "multiple_drop_down_list") }
      let(:dossiers) { procedure.dossiers }

      before do
        dossier_with_value.champ_data.first.update!(value: champ_value)
      end

      let(:champ_value) { "[\"Fromage \\\"blanc\\\"\",\"Fromage\"]" }

      context "when searching for a basic value" do
        let(:search_terms) { ["Fromage"] }

        it "returns the correct ids" do
          expect(subject).to match_array([dossier_with_value.id])
        end
      end

      context "when searching for a value with quotes" do
        let(:search_terms) { [%{Fromage "blanc"}] }

        it "returns the correct ids" do
          expect(subject).to match_array([dossier_with_value.id])
        end
      end
    end

    context "with a yes no champ not mandatory" do
      let_it_be(:procedure) { create(:procedure, public_type_de_champs: [{ type: :yes_no, mandatory: false, libelle: "oui/non" }]) }
      let(:dossier_with_yes) { create(:dossier, :en_instruction, procedure:) }
      let(:dossier_with_no) { create(:dossier, :en_instruction, procedure:) }
      let(:dossier_not_filled) { create(:dossier, :en_instruction, procedure:) }

      let(:column) { procedure.find_column(label: "oui/non") }
      let(:dossiers) { procedure.dossiers }

      before do
        dossier_with_yes.champ_data.first.update!(value: "true")
        dossier_with_no.champ_data.first.update!(value: "false")
        dossier_not_filled.champ_data.first.destroy!
      end

      context "when searching for a yes" do
        let(:search_terms) { ["true"] }

        it "returns the correct ids" do
          expect(subject).to match_array([dossier_with_yes.id])
        end
      end

      context "when searching for a no" do
        let(:search_terms) { ["false"] }

        it "returns the correct ids" do
          expect(subject).to match_array([dossier_with_no.id])
        end
      end

      context "when searching for a nil" do
        let(:search_terms) { [Column::NOT_FILLED_VALUE] }

        it "returns the correct ids" do
          expect(subject).to match_array([dossier_not_filled.id])
        end
      end
    end

    context "with a checkbox champ not mandatory" do
      let_it_be(:procedure) { create(:procedure, public_type_de_champs: [{ type: :checkbox, mandatory: false, libelle: "checkbox" }]) }
      let(:dossier_with_checked) { create(:dossier, :en_instruction, procedure:) }
      let(:dossier_not_checked) { create(:dossier, :en_instruction, procedure:) }

      before do
        dossier_with_checked.champ_data.first.update!(value: "true")
        dossier_not_checked.champ_data.first.destroy!
      end

      let(:column) { procedure.find_column(label: "checkbox") }
      let(:dossiers) { procedure.dossiers }

      context "when searching for a checked" do
        let(:search_terms) { ["true"] }

        it "returns the correct ids" do
          expect(subject).to match_array([dossier_with_checked.id])
        end
      end

      context "when searching for a not checked" do
        let(:search_terms) { ["false"] }

        it "returns the correct ids" do
          expect(subject).to match_array([dossier_not_checked.id])
        end
      end
    end

    context "with a checkbox champ not mandatory" do
      let_it_be(:procedure) { create(:procedure, public_type_de_champs: [{ type: :checkbox, mandatory: false, libelle: "checkbox" }]) }
      let(:dossier_with_checked) { create(:dossier, :en_instruction, procedure:) }
      let(:dossier_not_checked) { create(:dossier, :en_instruction, procedure:) }

      before do
        dossier_with_checked.champ_data.first.update!(value: "true")
        dossier_not_checked.champ_data.first.destroy!
      end

      let(:column) { procedure.find_column(label: "checkbox") }
      let(:dossiers) { procedure.dossiers }

      context "when searching for a checked" do
        let(:search_terms) { ["true"] }

        it "returns the correct ids" do
          expect(subject).to match_array([dossier_with_checked.id])
        end
      end

      context "when searching for a not checked" do
        let(:search_terms) { ["false"] }

        it "returns the correct ids" do
          expect(subject).to match_array([dossier_not_checked.id])
        end
      end
    end

    context "with a drop_down_list champ" do
      let_it_be(:procedure) { create(:procedure, public_type_de_champs: [{ type: :drop_down_list, libelle: "drop_down_list", options: ["Fromage", "Dessert", "Chocolat"] }]) }
      let(:dossier_with_fromage) { create(:dossier, :en_instruction, procedure:) }
      let(:dossier_with_dessert) { create(:dossier, :en_instruction, procedure:) }
      let(:dossier_with_chocolat) { create(:dossier, :en_instruction, procedure:) }

      before do
        dossier_with_fromage.champ_data.first.update!(value: "Fromage")
        dossier_with_dessert.champ_data.first.update!(value: "Dessert")
        dossier_with_chocolat.champ_data.first.update!(value: "Chocolat")
      end

      let(:column) { procedure.find_column(label: "drop_down_list") }
      let(:dossiers) { procedure.dossiers }

      context "when searching for fromage" do
        let(:search_terms) { ["Fromage"] }

        it "returns the correct ids" do
          expect(subject).to match_array([dossier_with_fromage.id])
        end
      end

      context "when searching for fromage OR dessert" do
        let(:search_terms) { ["Fromage", "Dessert"] }

        it "returns the correct ids" do
          expect(subject).to match_array([dossier_with_fromage.id, dossier_with_dessert.id])
        end
      end
    end

    context "with a pays champ" do
      let_it_be(:procedure) { create(:procedure, public_type_de_champs: [{ type: :pays, libelle: "pays" }]) }
      let(:dossier_fr) { create(:dossier, :en_instruction, procedure:) }
      let(:dossier_de) { create(:dossier, :en_instruction, procedure:) }

      before do
        dossier_fr.champ_data.first.update!(value: 'FR')
        dossier_de.champ_data.first.update!(value: 'DE')
      end

      let(:column) { procedure.find_column(label: "pays") }
      let(:dossiers) { procedure.dossiers }

      context "when filtering by country code" do
        let(:search_terms) { ["FR"] }

        it "matches only the dossier with this code" do
          expect(subject).to match_array([dossier_fr.id])
        end
      end
    end

    context "with a date champ" do
      let_it_be(:procedure) { create(:procedure, public_type_de_champs: [{ type: :date, libelle: "date" }]) }

      subject { column.filtered_ids(dossiers, filter) }

      let(:column) { procedure.find_column(label: "date") }
      let(:dossiers) { procedure.dossiers }

      context "when searching with before operator" do
        let(:dossier) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier2) { create(:dossier, :en_instruction, procedure:) }

        before do
          dossier.champ_data.first.update!(value: "2025-02-13")
          dossier2.champ_data.first.update!(value: "2025-02-15")
        end

        let(:filter) { { operator: 'before', value: ["2025-02-14"] } }

        it "returns the correct ids" do
          expect(subject).to eq([dossier.id])
        end
      end

      context "when searching with after operator" do
        let(:dossier) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier2) { create(:dossier, :en_instruction, procedure:) }

        before do
          dossier.champ_data.first.update!(value: "2025-02-13")
          dossier2.champ_data.first.update!(value: "2025-02-15")
        end

        let(:filter) { { operator: 'after', value: ["2025-02-14"] } }

        it "returns the correct ids" do
          expect(subject).to eq([dossier2.id])
        end
      end

      # update_filter neither whitelists the operator nor validates the date, so
      # both of these reach the column.
      context "when searching with a date the filter form let through" do
        let(:dossier) { create(:dossier, :en_instruction, procedure:) }

        before { dossier.champ_data.first.update!(value: "2025-02-13") }

        context "out of range" do
          let(:filter) { { operator: 'before', value: ['2024-13-45'] } }

          it { expect(subject).to eq([dossier.id]) }
        end

        context "unparseable" do
          let(:filter) { { operator: 'after', value: ['abc'] } }

          it { expect(subject).to eq([dossier.id]) }
        end
      end

      context "when searching with this_month operator" do
        let(:filter) { { operator: 'this_month' } }

        let(:dossier_at_the_beginning_of_the_month) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_at_the_end_of_the_month) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_month_before) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_month_after) { create(:dossier, :en_instruction, procedure:) }

        before do
          dossier_at_the_beginning_of_the_month.champ_data.first.update!(value: "2025-02-01")
          dossier_at_the_end_of_the_month.champ_data.first.update!(value: "2025-02-28")
          dossier_month_before.champ_data.first.update!(value: "2025-01-13")
          dossier_month_after.champ_data.first.update!(value: "2025-03-13")

          travel_to(Time.zone.parse("2025-02-13"))
        end

        it "returns dossiers from this month" do
          expect(subject).to match_array([dossier_at_the_beginning_of_the_month.id, dossier_at_the_end_of_the_month.id])
        end
      end

      context "when searching with this_week operator" do
        let(:filter) { { operator: 'this_week' } }

        let(:dossier_at_the_beginning_of_the_week) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_at_the_end_of_the_week) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_week_before) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_week_after) { create(:dossier, :en_instruction, procedure:) }

        before do
          dossier_at_the_beginning_of_the_week.champ_data.first.update!(value: "2025-02-03")
          dossier_at_the_end_of_the_week.champ_data.first.update!(value: "2025-02-09")
          dossier_week_before.champ_data.first.update!(value: "2025-02-02")
          dossier_week_after.champ_data.first.update!(value: "2025-02-10")

          travel_to(Time.zone.parse("2025-02-08"))
        end

        it "returns dossiers from this week" do
          expect(subject).to match_array([dossier_at_the_beginning_of_the_week.id, dossier_at_the_end_of_the_week.id])
        end
      end

      context "when searching with this_year operator" do
        let(:filter) { { operator: 'this_year' } }

        let(:dossier_at_the_beginning_of_the_year) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_at_the_end_of_the_year) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_year_before) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_year_after) { create(:dossier, :en_instruction, procedure:) }

        before do
          dossier_at_the_beginning_of_the_year.champ_data.first.update!(value: "2024-01-01")
          dossier_at_the_end_of_the_year.champ_data.first.update!(value: "2024-12-31")
          dossier_year_before.champ_data.first.update!(value: "2023-12-31")
          dossier_year_after.champ_data.first.update!(value: "2025-01-01")

          travel_to(Time.zone.parse("2024-02-13"))
        end

        it "returns dossiers from this year" do
          expect(subject).to match_array([dossier_at_the_beginning_of_the_year.id, dossier_at_the_end_of_the_year.id])
        end
      end
    end

    context "with a datetime champ" do
      let_it_be(:procedure) { create(:procedure, public_type_de_champs: [{ type: :datetime, libelle: "datetime" }]) }

      subject { column.filtered_ids(dossiers, filter) }

      let(:column) { procedure.find_column(label: "datetime") }
      let(:dossiers) { procedure.dossiers }

      context "when searching with before operator" do
        let(:dossier) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier2) { create(:dossier, :en_instruction, procedure:) }

        before do
          dossier.champ_data.first.update!(value: "2025-02-13T12:00:00+01:00")
          dossier2.champ_data.first.update!(value: "2025-02-15T12:00:00+01:00")
        end

        let(:filter) { { operator: 'before', value: ["2025-02-14"] } }

        it "returns the correct ids" do
          expect(subject).to eq([dossier.id])
        end
      end

      context "when searching with after operator" do
        let(:dossier) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier2) { create(:dossier, :en_instruction, procedure:) }

        before do
          dossier.champ_data.first.update!(value: "2025-02-13T12:00:00+01:00")
          dossier2.champ_data.first.update!(value: "2025-02-15T12:00:00+01:00")
        end

        let(:filter) { { operator: 'after', value: ["2025-02-14"] } }

        it "returns the correct ids" do
          expect(subject).to eq([dossier2.id])
        end
      end

      # update_filter neither whitelists the operator nor validates the date, so
      # both of these reach the column.
      context "when searching with a date the filter form let through" do
        let(:dossier) { create(:dossier, :en_instruction, procedure:) }

        before { dossier.champ_data.first.update!(value: "2025-02-13") }

        context "out of range" do
          let(:filter) { { operator: 'before', value: ['2024-13-45'] } }

          it { expect(subject).to eq([dossier.id]) }
        end

        context "unparseable" do
          let(:filter) { { operator: 'after', value: ['abc'] } }

          it { expect(subject).to eq([dossier.id]) }
        end
      end

      context "when searching with this_week operator" do
        let(:filter) { { operator: 'this_week' } }

        let(:dossier_at_the_beginning_of_the_week) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_at_the_end_of_the_week) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_week_before) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_week_after) { create(:dossier, :en_instruction, procedure:) }

        before do
          dossier_at_the_beginning_of_the_week.champ_data.first.update!(value: "2025-02-03T12:00:00+01:00")
          dossier_at_the_end_of_the_week.champ_data.first.update!(value: "2025-02-09T12:00:00+01:00")
          dossier_week_before.champ_data.first.update!(value: "2025-02-02T12:00:00+01:00")
          dossier_week_after.champ_data.first.update!(value: "2025-02-10T12:00:00+01:00")

          travel_to(Time.zone.parse("2025-02-08"))
        end

        it "returns dossiers from this week" do
          expect(subject).to match_array([dossier_at_the_beginning_of_the_week.id, dossier_at_the_end_of_the_week.id])
        end
      end

      context "when searching with this_month operator" do
        let(:filter) { { operator: 'this_month' } }

        let(:dossier_at_the_beginning_of_the_month) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_at_the_end_of_the_month) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_month_before) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_month_after) { create(:dossier, :en_instruction, procedure:) }

        before do
          dossier_at_the_beginning_of_the_month.champ_data.first.update!(value: "2025-02-01T12:00:00+01:00")
          dossier_at_the_end_of_the_month.champ_data.first.update!(value: "2025-02-28T12:00:00+01:00")
          dossier_month_before.champ_data.first.update!(value: "2025-01-13T12:00:00+01:00")
          dossier_month_after.champ_data.first.update!(value: "2025-03-13T12:00:00+01:00")

          travel_to(Time.zone.parse("2025-02-13"))
        end

        it "returns dossiers from this month" do
          expect(subject).to match_array([dossier_at_the_beginning_of_the_month.id, dossier_at_the_end_of_the_month.id])
        end
      end

      context "when searching with this_year operator" do
        let(:filter) { { operator: 'this_year' } }

        let(:dossier_at_the_beginning_of_the_year) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_at_the_end_of_the_year) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_year_before) { create(:dossier, :en_instruction, procedure:) }
        let(:dossier_year_after) { create(:dossier, :en_instruction, procedure:) }

        before do
          dossier_at_the_beginning_of_the_year.champ_data.first.update!(value: "2024-01-01T12:00:00+01:00")
          dossier_at_the_end_of_the_year.champ_data.first.update!(value: "2024-12-31T12:00:00+01:00")
          dossier_year_before.champ_data.first.update!(value: "2023-12-31T12:00:00+01:00")
          dossier_year_after.champ_data.first.update!(value: "2025-01-01T12:00:00+01:00")

          travel_to(Time.zone.parse("2024-02-13"))
        end

        it "returns dossiers from this year" do
          expect(subject).to match_array([dossier_at_the_beginning_of_the_year.id, dossier_at_the_end_of_the_year.id])
        end
      end
    end
  end

  private

  def expect_type_de_champ_values(type, assertion)
    type_de_champ = type_de_champs.find { _1.type_champ == type }
    champ = dossier.send(:filled_champ, type_de_champ)
    columns = type_de_champ.columns(procedure_id: procedure.id)
    expect(columns.map { _1.value(champ) }).to assertion
  end

  def retrieve_champ(type)
    type_de_champ = type_de_champs.find { _1.type_champ == type }
    dossier.send(:filled_champ, type_de_champ)
  end
end
