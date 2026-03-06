# frozen_string_literal: true

describe EditableChamp::RepetitionComponent, type: :component do
  include ChampAriaLabelledbyHelper

  describe "#row_has_errors?" do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :repetition, libelle: 'Répétition', children: [{ type: :text, libelle: 'Texte', mandatory: true }] }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:repetition_champ) { dossier.project_champs_public.first }
    let(:row_champ) { repetition_champ.rows.first.first }

    subject(:component) do
      comp = nil
      ActionView::Base.empty.form_for(repetition_champ, url: '/') do |form|
        comp = described_class.new(champ: repetition_champ, form:)
      end
      comp
    end

    context "when the row has no errors" do
      it "returns false" do
        expect(component.row_has_errors?(row_champ.row_id)).to be false
      end
    end

    context "when the dossier has nested errors for a champ in the row" do
      before do
        # Clear the value to make the mandatory field fail validation
        row_champ.value = nil
        row_champ.save!
        dossier.reload
        dossier.check_mandatory_and_visible_champs_public
      end

      it "returns true" do
        expect(dossier.errors).not_to be_empty
        expect(component.row_has_errors?(row_champ.row_id)).to be true
      end
    end
  end

  describe "the champ label or legend text" do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :repetition, libelle: 'Répétition', children: }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:repetition_champ) { dossier.project_champs_public.first }

    subject(:render) do
      component = nil
      ActionView::Base.empty.form_for(repetition_champ, url: '/') do |form|
        component = described_class.new(champ: repetition_champ, form:)
      end

      render_inline(component)
    end

    before { subject }

    shared_examples "has the repetition legend with no row number" do
      it do
        expect(page).to have_selector(:xpath, "//legend[normalize-space(text())='Répétition']")
      end
    end

    context "when there is one champ per row" do
      context "when the champ has a label before the input (ex: text)" do
        let(:children) { [{ type: :text, libelle: 'Prénom', mandatory: false }] }

        it_behaves_like "has the repetition legend with no row number"
        it do
          expect(page).to have_selector("label", text: "[1]\n\nPrénom")
        end
      end

      context "when the champ has a label, in a checkbox (ex: checkbox)" do
        let(:children) { [{ type: :checkbox, libelle: 'Je suis une checkbox', mandatory: false }] }

        it_behaves_like "has the repetition legend with no row number"
        it do
          expect(page).to have_selector("label", text: "[1]\n\nJe suis une checkbox")
        end
      end

      context "when the champ has a legend around the input (ex: choix simple)" do
        let(:children) { [{ type: :drop_down_list, libelle: 'Votre ville', options: ['Paris', 'Lyon', 'Marseille'] }] }

        it_behaves_like "has the repetition legend with no row number"
        it do
          expect(page).to have_selector("legend", text: "[1]\n\nVotre ville")
        end
      end
    end

    shared_examples "has the repetition legend with row number" do
      it do
        expect(page).to have_selector(:xpath, "//legend[contains(., '[1]') and contains(substring-after(., '[1]'), 'Répétition')]")
      end
    end

    context "when there is multiple champ per row" do
      let(:children) { [champ, { type: :text, libelle: 'Nom', mandatory: false }] }

      context "when the champ has a label before the input (ex: text)" do
        let(:champ) { { type: :text, libelle: 'Prénom', mandatory: false } }

        it_behaves_like "has the repetition legend with row number"
        it do
          expect(page).to have_selector(:xpath, "//label[normalize-space(text())='Prénom']")
        end
      end

      context "when the champ has a label, in a checkbox (ex: checkbox)" do
        let(:champ) { { type: :checkbox, libelle: 'Je suis une checkbox', mandatory: false } }

        it_behaves_like "has the repetition legend with row number"
        it do
          expect(page).to have_selector(:xpath, "//label[normalize-space(.)='Je suis une checkbox']")
        end
      end

      context "when the champ has a legend around the input (ex: choix simple)" do
        let(:champ) { { type: :drop_down_list, libelle: 'Votre ville', options: ['Paris', 'Lyon', 'Marseille'] } }

        it_behaves_like "has the repetition legend with row number"
        it do
          expect(page).to have_selector(:xpath, "//legend[normalize-space(text())='Votre ville']")
        end
      end
    end
  end

  describe "aria-labelledby" do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :repetition, libelle: 'Répétition', children: }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:repetition_champ) { dossier.project_champs_public.first }

    subject(:render) do
      component = nil
      ActionView::Base.empty.form_for(repetition_champ, url: '/') do |form|
        component = described_class.new(champ: repetition_champ, form:)
      end

      render_inline(component)
    end

    context "when the procedure has only one champ per row" do
      let(:champ) { repetition_champ.rows.first.first }

      context "for type text" do
        let(:children) { [{ type: :text, libelle: 'Prénom', mandatory: false }] }

        it do
          # we should match
          # aria-labelledby="champ-66-legend champ-67-01JWAZPQ0MZFCTPJ4SRV8YSGP2-label"
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")

          # should have a fieldset legend for the repetition
          expect(subject).to have_selector("legend[id='#{repetition_fieldset_legend_id(repetition_champ)}']", text: "Répétition")

          # should not have a fieldset legend for the row
          expect(subject).not_to have_selector("legend[id='#{repetition_row_fieldset_legend_id(repetition_champ, champ.row_id)}']")

          # the label in the rows should contain the row number
          expect(subject).to have_selector("label[id='#{input_label_id(champ)}']", text: "[1]\n\nPrénom")
        end
      end

      context "for textarea" do
        let(:children) { [{ type: :textarea }] }

        it do
          expect(subject).to have_selector("textarea[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type email" do
        let(:children) { [{ type: :email }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type date" do
        let(:children) { [{ type: :date }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type datetime" do
        let(:children) { [{ type: :datetime }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type dossier_link" do
        let(:children) { [{ type: :dossier_link }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type civilite" do
        let(:children) { [{ type: :civilite, libelle: 'Civilité', mandatory: false }] }

        it do
          subject

          expect(page).to have_selector("legend[id='#{champ_fieldset_legend_id(champ)}']", text: "[1]\n\nCivilité")

          expect(page).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{champ_fieldset_legend_id(champ)} #{input_label_id(champ, :female)}']")
          expect(page).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{champ_fieldset_legend_id(champ)} #{input_label_id(champ, :male)}']")
        end
      end

      context "for type phone" do
        let(:children) { [{ type: :phone }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type number" do
        let(:children) { [{ type: :number }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type decimal_number" do
        let(:children) { [{ type: :decimal_number }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type integer_number" do
        let(:children) { [{ type: :integer_number }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type iban" do
        let(:children) { [{ type: :iban }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type checkbox" do
        let(:children) { [{ type: :checkbox }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type drop_down_list" do
        context "as radio button" do
          let(:children) { [{ type: :drop_down_list, drop_down_options: ["Option 1", "Option 2"] }] }

          it do
            champ.options_for_select_with_other.each do |_option, value|
              expect(subject).to have_selector("input[type='radio'][aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{champ_fieldset_legend_id(champ)} #{input_label_id(champ, value)}']")
            end
          end
        end

        context "as select" do
          let(:children) { [{ type: :drop_down_list, drop_down_options: Array.new(6) { "Option #{it + 1}" } }] }

          it do
            expect(subject).to have_selector("select[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
          end
        end

        context "as combobox" do
          let(:children) { [{ type: :drop_down_list, drop_down_options: Array.new(30) { "Option #{it + 1}" } }] }
          it do
            subject

            props = JSON.parse(page.first('react-component')['props'])
            expect(props['ariaLabelledbyPrefix']).to eq(repetition_fieldset_legend_id(repetition_champ))
            expect(props['labelId']).to eq(input_label_id(champ))
          end
        end
      end

      context "for type engagement_juridique" do
        let(:children) { [{ type: :engagement_juridique }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type yes_no" do
        let(:children) { [{ type: :yes_no }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{champ_fieldset_legend_id(champ)} #{input_label_id(champ, :yes)}']")
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{champ_fieldset_legend_id(champ)} #{input_label_id(champ, :no)}']")
        end
      end

      context "for type siret" do
        let(:children) { [{ type: :siret }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type rna" do
        let(:children) { [{ type: :rna }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type rnf" do
        let(:children) { [{ type: :rnf }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type cnaf" do
        let(:children) { [{ type: :cnaf }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']", count: 2)
        end
      end

      context "for type dgfip" do
        let(:children) { [{ type: :dgfip }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']", count: 2)
        end
      end

      context "for type pole_emploi" do
        let(:children) { [{ type: :pole_emploi }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type mesri" do
        let(:children) { [{ type: :mesri }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type regions" do
        let(:children) { [{ type: :regions }] }

        it do
          expect(subject).to have_selector("select[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type pays" do
        let(:children) { [{ type: :pays }] }

        it do
          expect(subject).to have_selector("select[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type epci" do
        let(:children) { [{ type: :epci }] }

        before do
          champ.code_departement = '75'
          champ.save!
        end

        it do
          expect(subject).to have_selector("select[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{champ_fieldset_legend_id(champ)} #{input_label_id(champ, :code_departement)}']")
          expect(subject).to have_selector("select[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{champ_fieldset_legend_id(champ)} #{input_label_id(champ, :value)}']")
        end
      end

      context "for type departements" do
        let(:children) { [{ type: :departements }] }

        it do
          expect(subject).to have_selector("select[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type formatted" do
        let(:children) { [{ type: :formatted }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      xcontext "for type referentiel" do
        let!(:referentiel) { create(:referentiel, :configured, name: 'test') }
        let(:children) { [{ type: :referentiel, referentiel_id: referentiel.id }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type communes" do
        let(:children) { [{ type: :communes }] }

        it do
          subject
          props = JSON.parse(page.first('react-component')['props'])
          expect(props['ariaLabelledbyPrefix']).to eq(repetition_fieldset_legend_id(repetition_champ))
          expect(props['labelId']).to eq(input_label_id(champ))
        end
      end

      context "for type multiple_drop_down_list" do
        context "as checkbox" do
          let(:children) { [{ type: :multiple_drop_down_list, drop_down_options: Array.new(3) { "Option #{it + 1}" } }] }

          it do
            champ.options_for_select_with_other.each do |_option, value|
              expect(subject).to have_selector("input[type='checkbox'][aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{champ_fieldset_legend_id(champ)} #{champ.checkbox_label_id(value)}']")
            end
          end
        end

        context "as combobox" do
          let(:children) { [{ type: :multiple_drop_down_list, drop_down_options: Array.new(30) { "Option #{it + 1}" } }] }

          it do
            subject
            props = JSON.parse(page.first('react-component')['props'])
            expect(props['ariaLabelledbyPrefix']).to eq(repetition_fieldset_legend_id(repetition_champ))
            expect(props['labelId']).to eq(input_label_id(champ))
          end
        end
      end

      context "for type linked_drop_down_list" do
        let(:children) { [{ type: :linked_drop_down_list }] }

        it do
          expect(subject).to have_selector("select[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type piece_justificative" do
        before do
          allow_any_instance_of(ApplicationController).to receive(:administrateur_signed_in?).and_return(false)
        end

        let(:children) { [{ type: :piece_justificative }] }

        it do
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type titre_identite" do
        let(:children) { [{ type: :titre_identite, mandatory: false }] }

        it do
          allow_any_instance_of(ActiveStorage::Attachment).to receive(:persisted?).and_return(false)
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{input_label_id(champ)}']")
        end
      end

      context "for type annuaire_education" do
        let(:children) { [{ type: :annuaire_education }] }

        it do
          subject
          props = JSON.parse(page.first('react-component')['props'])
          expect(props['ariaLabelledbyPrefix']).to eq(repetition_fieldset_legend_id(repetition_champ))
          expect(props['labelId']).to eq(input_label_id(champ))
        end
      end

      context "for type address" do
        let(:children) { [{ type: :address }] }

        it do
          # first legend of the repetition
          expect(subject).to have_selector("legend[id='#{repetition_fieldset_legend_id(repetition_champ)}']")

          # legend of the champ address
          expect(subject).to have_selector("legend[id='#{champ_fieldset_legend_id(champ)}']")

          # label of the main input
          expect(subject).to have_selector("label[id='#{input_label_id(champ)}']")

          # input
          props = JSON.parse(page.first("react-component")['props'])
          expect(props['ariaLabelledbyPrefix']).to eq([repetition_fieldset_legend_id(repetition_champ), champ_fieldset_legend_id(champ)].join(' '))
          expect(props['labelId']).to eq(input_label_id(champ))

          # not in ban checkbox
          expect(subject).to have_selector("label[id='#{input_label_id(champ, :not_in_ban)}']")

          # input of the not in ban checkbox
          expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{champ_fieldset_legend_id(champ)} #{input_label_id(champ, :not_in_ban)}']")
        end

        context "when the address is not in the BAN" do
          context "not in France" do
            before do
              champ.country_code = 'US'
              champ.not_in_ban = 'true'
              champ.save!
            end

            it do
              # first legend of the repetition
              expect(subject).to have_selector("legend[id='#{repetition_fieldset_legend_id(repetition_champ)}']")
              # second legend of the champ address
              expect(subject).to have_selector("legend[id='#{champ_fieldset_legend_id(champ)}']")

              # label of the country select
              expect(subject).to have_selector("label[id='#{input_label_id(champ, :country_code)}']")
              # select of the country
              expect(subject).to have_selector("select[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{champ_fieldset_legend_id(champ)} #{input_label_id(champ, :country_code)}']")

              # label of the street address
              expect(subject).to have_selector("label[id='#{input_label_id(champ, :street_address)}']")
              # input of the street address
              expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{champ_fieldset_legend_id(champ)} #{input_label_id(champ, :street_address)}']")

              # label of the city input
              expect(subject).to have_selector("label[id='#{input_label_id(champ, :city_name)}']")
              # input of the city
              expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{champ_fieldset_legend_id(champ)} #{input_label_id(champ, :city_name)}']")

              # label of the postal code input
              expect(subject).to have_selector("label[id='#{input_label_id(champ, :postal_code)}']")
              # input of the postal code
              expect(subject).to have_selector("input[aria-labelledby='#{repetition_fieldset_legend_id(repetition_champ)} #{champ_fieldset_legend_id(champ)} #{input_label_id(champ, :postal_code)}']")
            end
          end

          context "in France" do
            before do
              champ.country_code = 'FR'
              champ.not_in_ban = 'true'
              champ.save!
            end

            it do
              # label of the commune input
              expect(subject).to have_selector("label[id='#{input_label_id(champ, :commune_name)}']")
              # input of the commune
              props = JSON.parse(page.first(".not-in-ban-group react-component")['props'])
              expect(props['ariaLabelledbyPrefix']).to eq("#{repetition_fieldset_legend_id(repetition_champ)} #{champ_fieldset_legend_id(champ)}")
              expect(props['labelId']).to eq(input_label_id(champ, :commune_name))
            end
          end
        end
      end

      context "for type carte" do
        let(:children) { [{ type: :carte }] }

        it do
          subject
          attribute = JSON.parse(page.first("react-component")['props'])['ariaLabelledbyPrefix']
          expect(attribute).to eq("#{repetition_fieldset_legend_id(repetition_champ)} #{champ_fieldset_legend_id(champ)}")
        end
      end
    end

    context "when the procedure has multiple champs per row" do
      let(:children) { [{ type: :text, libelle: 'Prénom' }, { type: :text, libelle: 'Nom' }] }
      let(:text_champ) { repetition_champ.rows.first.first }
      let(:text_champ_2) { repetition_champ.rows.first.last }

      it "should have a fieldset legend for the repetition" do
        subject
        # should have a fieldset legend for the repetition
        expect(page).to have_selector("legend[id='#{repetition_fieldset_legend_id(repetition_champ)}']", text: "Répétition")

        # should have a fieldset legend for the row with the row number
        expect(page).to have_selector(:xpath, "//legend[@id='#{repetition_row_fieldset_legend_id(repetition_champ, text_champ.row_id)}' and contains(., '[1]') and contains(substring-after(., '[1]'), 'Répétition')]")

        # the labels in the row
        expect(page).to have_selector("label[id='#{input_label_id(text_champ)}']", text: "Prénom")
        expect(page).to have_selector("label[id='#{input_label_id(text_champ_2)}']", text: "Nom")

        # should have an aria-labelledby that contains the row fieldset id and the label id
        expect(page).to have_selector("input[aria-labelledby='#{repetition_row_fieldset_legend_id(repetition_champ, text_champ.row_id)} #{input_label_id(text_champ)}']")
        expect(page).to have_selector("input[aria-labelledby='#{repetition_row_fieldset_legend_id(repetition_champ, text_champ_2.row_id)} #{input_label_id(text_champ_2)}']")
      end
    end
  end
end
