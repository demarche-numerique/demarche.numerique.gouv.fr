# frozen_string_literal: true

RSpec.describe Message::DossierModifierParInstructeurComponent, type: :component do
  let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :text, libelle: "Texte", stable_id: 99 }]) }
  let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }

  subject { render_inline(described_class.new(dossier:, changed_columns:, motivation:)) }

  context 'when the changed columns are known' do
    let(:motivation) { nil }
    let(:instructeur) { create(:instructeur) }
    let(:changed_columns) do
      dossier.with_instructeur_buffer_stream do
        dossier.public_champ_data_for_update('99', updated_by: instructeur.email)
          .assign_attributes(value: "Nouvelle valeur")
      end
      dossier.save!
      dossier.instructeur_submit_en_construction!(instructeur:)
      dossier.traitements.last.changed_columns
    end

    it 'renders the detailed list of changes' do
      expect(subject).to have_text('a apporté les modifications suivantes')
      expect(subject).to have_text('Nouvelle valeur')
    end
  end

  context 'when the changed columns are unknown' do
    let(:changed_columns) { [] }
    let(:motivation) { nil }

    it 'renders the generic message' do
      expect(subject).to have_text('a apporté des modifications')
      expect(subject).not_to have_text('a apporté les modifications suivantes')
    end
  end

  describe '.render' do
    let(:changed_columns) { [] }

    around do |example|
      previous = ActionView::Base.annotate_rendered_view_with_filenames
      ActionView::Base.annotate_rendered_view_with_filenames = true
      example.run
      ActionView::Base.annotate_rendered_view_with_filenames = previous
    end

    it 'strips template annotation comments from the persisted body' do
      body = described_class.render(dossier:, changed_columns:)

      expect(body).not_to include('<!-- BEGIN')
      expect(body).not_to include('<!-- END')
      expect(body).to include('a apporté des modifications')
    end
  end

  context 'with a motivation' do
    let(:changed_columns) { [] }
    let(:motivation) { "Merci de <strong>vérifier</strong> votre saisie" }

    it 'renders the motivation' do
      expect(subject).to have_text('Merci de vérifier votre saisie')
    end

    context 'when the motivation contains unsafe markup' do
      let(:motivation) { "Coquille corrigée<script>alert('xss')</script>" }

      it 'sanitizes the motivation' do
        expect(subject.to_html).to include('Coquille corrigée')
        expect(subject.to_html).not_to include('<script>')
      end
    end
  end
end
