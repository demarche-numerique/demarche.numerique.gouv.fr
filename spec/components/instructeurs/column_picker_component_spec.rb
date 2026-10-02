# frozen_string_literal: true

describe Instructeurs::ColumnPickerComponent, type: :component do
  let(:component) { described_class.new(procedure:, procedure_presentation:, instructeur:) }

  let(:procedure) { create(:procedure) }
  let(:procedure_id) { procedure.id }

  let(:instructeur) { create(:instructeur) }
  let(:assign_to) { create(:assign_to, procedure:, instructeur:) }
  let(:procedure_presentation) { create(:procedure_presentation, assign_to:) }

  let(:other_instructeur) { create(:instructeur) }
  let(:other_assign_to) { create(:assign_to, procedure:, instructeur: other_instructeur) }
  let(:other_presentation) { create(:procedure_presentation, assign_to: other_assign_to) }

  before do
    allow(component).to receive(:instructeur_is_admin?).and_return(true)
  end

  describe "#displayable_columns_for_select" do
    let(:default_user_email) { Column.new(procedure_id:, label: 'email', table: 'user', column: 'email') }
    let(:excluded_displayable_field) { Column.new(procedure_id:, label: "label1", table: "table1", column: "column1", displayable: false) }
    let(:email_column_id) { default_user_email.id }
    subject { component.displayable_columns_for_select }

    before do
      allow(procedure).to receive(:columns).and_return([
        default_user_email,
        excluded_displayable_field,
      ])
    end

    it { is_expected.to eq([[["email", email_column_id]], [email_column_id]]) }
  end

  describe "admin default toggle" do
    context "when instructeur/admin owns the active default presentation" do
      before do
        procedure.update!(
          admin_default_procedure_presentation_active: true,
          admin_default_procedure_presentation_id: procedure_presentation.id
        )

        allow(instructeur)
          .to receive(:procedure_presentation_for_procedure_id)
          .with(procedure.id)
          .and_return(procedure_presentation)
      end

      it "is checked and enabled" do
        expect(component.toggle_checked?).to be true
        expect(component.toggle_disabled?).to be false
      end
    end

    context "when default presentation is owned by another instructeur/admin" do
      before do
        procedure.update!(
          admin_default_procedure_presentation_active: true,
          admin_default_procedure_presentation_id: other_presentation.id
        )

        allow(instructeur)
          .to receive(:procedure_presentation_for_procedure_id)
          .with(procedure.id)
          .and_return(procedure_presentation)
      end

      it "is unchecked and disabled" do
        expect(component.toggle_checked?).to be false
        expect(component.toggle_disabled?).to be true
      end

      it "displays a message indicating who owns the default" do
        allow(component).to receive(:default_admin).and_return(other_instructeur)

        rendered = render_inline(component)

        expect(rendered.to_html)
          .to include("Personnalisation déjà appliquée par #{other_instructeur.email}")
      end
    end
  end

  describe "reset to admin default button" do
    subject(:rendered) { render_inline(component) }

    let(:button_label) { "Remplacer mes colonnes par celles de l’administrateur" }
    let(:default_presentation_id) { other_presentation.id }
    let(:customized) { true }

    before do
      allow(component).to receive(:instructeur_is_admin?).and_return(false)
      procedure_presentation.update!(customized:)
      procedure.update!(
        admin_default_procedure_presentation_active: true,
        admin_default_procedure_presentation_id: default_presentation_id
      )
    end

    context "when the instructeur replaced the admin default with their own columns" do
      it "displays the button" do
        expect(rendered).to have_button(button_label)
        expect(rendered).to have_text("définies par l’administrateur #{other_instructeur.email}")

        form_id = rendered.at_css("button[form]")["form"]
        expect(rendered).to have_css("form##{form_id}[action$='/reset_to_admin_default']", visible: :all)
      end
    end

    context "when the instructeur follows the admin default" do
      let(:customized) { false }

      it { expect(rendered).not_to have_button(button_label) }
    end

    context "when the instructeur owns the admin default" do
      let(:default_presentation_id) { procedure_presentation.id }

      it { expect(rendered).not_to have_button(button_label) }
    end

    context "when no admin default is active" do
      before { procedure.update!(admin_default_procedure_presentation_active: false, admin_default_procedure_presentation_id: nil) }

      it { expect(rendered).not_to have_button(button_label) }
    end
  end
end
