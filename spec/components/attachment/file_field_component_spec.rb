# frozen_string_literal: true

RSpec.describe Attachment::FileFieldComponent, type: :component do
  describe 'with has_many_attached (ChampData.piece_justificative_file)' do
    let_it_be(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champ_data.first }
    let(:context) { Attachment::Context.new(champ:) }

    it 'deduces max=10 and shows drop zone' do
      component = described_class.new(context:, drop_zone: :integrated)
      expect(component.max).to eq(10)
      expect(component.show_as_list?).to eq(true)
    end

    it 'shows uploader when no files' do
      component = described_class.new(context:, drop_zone: :integrated)
      expect(component.show_uploader?).to eq(true)
    end

    it 'hides uploader when max reached' do
      attachments = Array.new(10) do
        champ.piece_justificative_file.attach(io: StringIO.new('fake'), filename: "file#{_1}.pdf", content_type: 'application/pdf')
        champ.piece_justificative_file.attachments.last
      end
      component = described_class.new(context:, drop_zone: :integrated, attachments:)

      expect(component.show_uploader?).to eq(false)
    end
  end

  describe 'with has_one_attached (Procedure.logo)' do
    let(:procedure) { create(:procedure) }
    let(:context) { Attachment::Context.new(attached_file: procedure.logo) }

    it 'deduces max=1 and shows no list' do
      component = described_class.new(context:, drop_zone: :none)
      expect(component.max).to eq(1)
      expect(component.show_as_list?).to eq(false)
    end

    it 'shows uploader when empty' do
      component = described_class.new(context:, drop_zone: :none)
      expect(component.show_uploader?).to eq(true)
    end

    it 'hides uploader when file present' do
      procedure.logo.attach(io: StringIO.new('fake'), filename: 'logo.png', content_type: 'image/png')
      component = described_class.new(context:, drop_zone: :none, attachments: [procedure.logo.attachment])

      expect(component.show_uploader?).to eq(false)
    end
  end

  describe 'override max (RIB case: has_many but max=1)' do
    let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champ_data.first }
    let(:context) { Attachment::Context.new(champ:) }

    it 'uses forced max=1 despite has_many' do
      component = described_class.new(context:, max: 1, drop_zone: :integrated)
      expect(component.max).to eq(1)
      expect(component.show_as_list?).to eq(false)
    end
  end

  describe 'drop_zone validation' do
    let_it_be(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }]) }
    let_it_be(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champ_data.first }
    let(:context) { Attachment::Context.new(champ:) }

    it 'accepts :none' do
      expect { described_class.new(context:, drop_zone: :none) }.not_to raise_error
    end

    it 'accepts :integrated' do
      expect { described_class.new(context:, drop_zone: :integrated) }.not_to raise_error
    end

    it 'rejects invalid values' do
      expect {
        described_class.new(context:, drop_zone: :remote)
      }.to raise_error(ArgumentError, /Invalid drop_zone/)
    end
  end

  describe 'drop zone accessible name (issue #13104)' do
    include ChampAriaLabelledbyHelper

    let_it_be(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }]) }
    let_it_be(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champ_data.first }
    let(:context) { Attachment::Context.new(champ:) }

    let(:drop_area) { render_inline(described_class.new(context:, drop_zone: :integrated)).at_css('.attachment-drop-area') }

    it 'names the drop zone via the field label instead of a generic aria-label' do
      expect(drop_area['aria-label']).to be_nil
      expect(drop_area['aria-labelledby']).to eq(input_label_id(champ))
    end

    it 'describes the drop zone via the format/size hints' do
      expect(drop_area['aria-describedby']).to include("#{champ.focusable_input_id}-hint")
    end
  end

  describe 'drop zone file input tab order (issue #13104)' do
    let_it_be(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }]) }
    let_it_be(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champ_data.first }
    let(:context) { Attachment::Context.new(champ:) }

    context 'with an integrated drop zone' do
      subject { render_inline(described_class.new(context:, drop_zone: :integrated)).to_html }

      it 'takes the file input out of the tab order (the drop zone button is the keyboard target)' do
        expect(subject).to have_selector('input[type="file"][tabindex="-1"]')
      end
    end

    context 'without a drop zone' do
      subject { render_inline(described_class.new(context:, drop_zone: :none)).to_html }

      it 'keeps the file input keyboard-focusable' do
        expect(subject).to have_no_selector('input[type="file"][tabindex]')
      end
    end
  end

  describe 'format indication hints' do
    subject { render_inline(described_class.new(context:, drop_zone: :integrated)).to_html }

    context 'when champ is a piece_justificative with titre_identite nature' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative, nature: 'titre_identite' }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:champ) { dossier.champ_data.first }
      let(:context) { Attachment::Context.new(champ:) }

      it 'renders exhaustive format list without tooltip' do
        expect(subject).to have_content('.jpg, .jpeg, .png')
        expect(subject).to have_no_selector('[role="tooltip"]')
      end
    end

    context 'when champ is a piece_justificative with no format limit' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:champ) { dossier.champ_data.first }
      let(:context) { Attachment::Context.new(champ:) }

      it 'does not render format info, only max size' do
        expect(subject).to have_content(/Taille maximale par fichier/)
        expect(subject).to have_no_content('Formats acceptés')
      end
    end

    context 'when champ is a piece_justificative limited to document_texte' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:champ) { dossier.champ_data.first }
      let(:context) { Attachment::Context.new(champ:) }

      before do
        champ.type_de_champ.update!(options: champ.type_de_champ.options.merge(
          pj_limit_formats: true,
          pj_format_families: ['document_texte']
        ))
      end

      it 'renders format info, tooltip and accessible button' do
        expect(subject).to have_content('document texte (.pdf, .docx...)')
        expect(subject).to have_selector('[role="tooltip"]')
        expect(subject).to have_selector('button[aria-label]')
      end
    end

    context 'when champ is a piece_justificative limited to document_texte + image_scan' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:champ) { dossier.champ_data.first }
      let(:context) { Attachment::Context.new(champ:) }

      before do
        champ.type_de_champ.update!(options: champ.type_de_champ.options.merge(
          pj_limit_formats: true,
          pj_format_families: ['document_texte', 'image_scan']
        ))
      end

      it 'renders both categories with top formats' do
        expect(subject).to have_content('document texte (.pdf, .docx...)')
        expect(subject).to have_content('image / scan (.jpeg, .png...)')
      end
    end

    context 'when champ is a piece_justificative with RIB nature' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative, nature: 'rib' }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:champ) { dossier.champ_data.first }
      let(:context) { Attachment::Context.new(champ:) }

      it 'renders exhaustive format list without tooltip' do
        expect(subject).to have_content('.pdf, .doc, .docx, .jpg, .jpeg, .png')
        expect(subject).to have_no_selector('[role="tooltip"]')
      end
    end
  end
end
