# frozen_string_literal: true

RSpec.describe Attachment::Validation do
  let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first }
  let(:attached_file) { champ.piece_justificative_file }
  let(:validation) { described_class.new(attached_file:) }

  describe '#allowed_extensions' do
    context 'with RIB nature (multiple specific formats)' do
      let(:types_de_champ_public) { [{ type: :piece_justificative, libelle: 'RIB', nature: 'RIB' }] }

      it 'returns extensions sorted according to EXTENSIONS_ORDER first, then alphabetically' do
        extensions = validation.allowed_extensions

        # RIB accepts: pdf, docx, odt, doc, txt, rtf, jpeg, png (8 formats > 5, will be truncated)
        # EXTENSIONS_ORDER = ['jpeg', 'png', 'pdf', 'zip']
        # Expected: jpeg, png, pdf first (from ORDER), then alphabetically sorted, truncated to 5 + '…'
        expect(extensions.first(3)).to eq(['jpeg', 'png', 'pdf'])
        expect(extensions.size).to eq(6)
        expect(extensions.last).to eq('…')
      end
    end

    context 'with piece_justificative standard (many formats, > 5)' do
      let(:types_de_champ_public) { [{ type: :piece_justificative, libelle: 'Document' }] }

      it 'truncates to first 5 extensions and adds ellipsis' do
        extensions = validation.allowed_extensions

        expect(extensions.size).to eq(6)
        expect(extensions.last).to eq('…')
        expect(extensions.first(5)).to all(be_a(String))
      end
    end
  end

  describe '#accept_attribute' do
    context 'with titre_identite nature (image formats only)' do
      let(:types_de_champ_public) { [{ type: :piece_justificative, libelle: 'Titre identité', nature: 'TITRE_IDENTITE' }] }

      it 'returns only image mime types' do
        accept = validation.accept_attribute

        expect(accept).to include('image/jpeg')
        expect(accept).to include('image/png')
        expect(accept).not_to include('application/pdf')
      end
    end
  end

  describe '#max_file_size' do
    context 'with titre_identite nature' do
      let(:types_de_champ_public) { [{ type: :piece_justificative, libelle: 'Titre identité', nature: 'TITRE_IDENTITE' }] }

      it 'returns 20 megabytes' do
        expect(validation.max_file_size).to eq(20.megabytes)
      end
    end

    context 'with standard piece_justificative' do
      let(:types_de_champ_public) { [{ type: :piece_justificative, libelle: 'Document' }] }

      it 'returns 200 megabytes' do
        expect(validation.max_file_size).to eq(200.megabytes)
      end
    end
  end
end
