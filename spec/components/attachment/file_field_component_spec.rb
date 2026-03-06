# frozen_string_literal: true

RSpec.describe Attachment::FileFieldComponent, type: :component do
  describe 'with has_many_attached (Champ.piece_justificative_file)' do
    let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champs.first }
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
    let(:champ) { dossier.champs.first }
    let(:context) { Attachment::Context.new(champ:) }

    it 'uses forced max=1 despite has_many' do
      component = described_class.new(context:, max: 1, drop_zone: :integrated)
      expect(component.max).to eq(1)
      expect(component.show_as_list?).to eq(false)
    end
  end

  describe 'drop_zone validation' do
    let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champs.first }
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
end
