# frozen_string_literal: true

describe EditableChamp::TitreIdentiteComponent, type: :component do
  let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
  let(:types_de_champ_public) { [{ type: :titre_identite }] }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first }

  let(:form) do
    instance_double(ActionView::Helpers::FormBuilder, object_name: "dossier[champs_public_attributes]", object: champ)
  end

  let(:component) { described_class.new(form:, champ:) }
  let(:expected_hint_id) { "#{champ.focusable_input_id}-pj-hint" }

  subject { render_inline(component).to_html }

  describe 'hint paragraph' do
    it 'renders a hint with the correct id and expected content' do
      expect(subject).to have_selector("p.fr-hint-text##{expected_hint_id}")
      expect(subject).to have_content(/Taille maximale/)
      expect(subject).to have_content(/Formats acceptés.+png, jpeg/)
    end
  end

  describe 'aria-describedby on file input' do
    it 'passes parent_hint_id to the EditComponent' do
      subject
      file_input = page.find('input[type=file]')
      expect(file_input['aria-describedby']).to include(expected_hint_id)
    end
  end
end
