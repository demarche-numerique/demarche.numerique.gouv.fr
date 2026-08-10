# frozen_string_literal: true

describe EditableChamp::ExplicationComponent, type: :component do
  let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.root_public_champs.first }

  let(:component) {
    described_class.new(form: instance_double(ActionView::Helpers::FormBuilder, object_name: "dossier[champs_public_attributes]"), champ:)
  }

  describe 'no description' do
    let(:types_de_champ_public) { [{ type: :explication }] }

    subject { render_inline(component).to_html }

    it { is_expected.not_to have_button("Lire plus") }
  end

  describe 'collapsed text is collapsed' do
    let(:types_de_champ_public) { [{ type: :explication, collapsible_explanation_enabled: "1", collapsible_explanation_text: "hide me" }] }

    subject { render_inline(component).to_html }

    it do
      is_expected.to have_button("Lire plus")
      is_expected.to have_selector(".fr-collapse", text: "hide me")
    end
  end
end
