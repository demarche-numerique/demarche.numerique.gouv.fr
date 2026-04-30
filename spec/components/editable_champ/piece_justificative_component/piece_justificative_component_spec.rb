# frozen_string_literal: true

describe EditableChamp::PieceJustificativeComponent, type: :component do
  let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
  let(:types_de_champ_public) { [{ type: :piece_justificative }] }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:champ) { dossier.champs.first }

  let(:component) {
    described_class.new(form: instance_double(ActionView::Helpers::FormBuilder, object_name: "dossier[champs_public_attributes]"), champ:)
  }

  let(:subject) {
    render_inline(component).to_html
  }

  context 'when there is a template' do
    let(:profil) { :user }

    before do
      allow_any_instance_of(ApplicationController).to receive(:administrateur_signed_in?).and_return(profil == :administrateur)
    end

    it 'renders a link to template' do
      expect(subject).to have_link('Télécharger le modèle')
      expect(subject).not_to have_text("éphémère")
    end

    context 'as an administrator' do
      let(:profil) { :administrateur }
      it 'warn about ephemeral template url' do
        expect(subject).to have_link('Télécharger le modèle')
        expect(subject).to have_text("éphémère")
      end
    end
  end

  context 'RIB nature' do
    let(:types_de_champ_public) { [{ type: :piece_justificative, nature: 'rib' }] }
    before { allow_any_instance_of(ApplicationController).to receive(:administrateur_signed_in?).and_return(false) }

    it 'limits to a single file' do
      expect(subject).to have_no_selector('input[multiple]')
    end
  end
end
