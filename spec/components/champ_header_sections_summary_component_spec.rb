# frozen_string_literal: true

RSpec.describe ViewableChamp::HeaderSectionsSummaryComponent, type: :component do
  include Logic

  subject { render_inline(component).to_html }

  let(:is_private) { false }
  let(:types_de_champ) do
    [
      { type: :header_section, level: 1 },
      { type: :text },
      { type: :header_section, level: 2 },
      { type: :repetition, children: [{ type: :text }, { type: :header_section, level: 1 }] },
      { type: :header_section, level: 3 },
      { type: :text },
    ]
  end
  let(:procedure) { create(:procedure, types_de_champ_public: types_de_champ, types_de_champ_private: types_de_champ) }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:component) { described_class.new(dossier:, is_private:) }
  let(:types_de_champ_public) { dossier.revision.root_types_de_champ_public.filter(&:header_section?) }
  let(:types_de_champ_private) { dossier.revision.root_types_de_champ_private.filter(&:header_section?) }
  let(:repetition_tdc) { dossier.revision.root_types_de_champ_public.find(&:repetition?) }
  let(:section_in_repetition) { repetition_tdc.flat_children(dossier.revision).find(&:header_section?) }

  context 'public' do
    it do
      types_de_champ_public.each { expect(subject).to have_selector("a[href='##{_1.html_id}']") }
    end

    it 'anchors the repetition, each of its rows and their sections' do
      row_ids = dossier.repetition_row_ids(repetition_tdc)
      expect(row_ids.size).to eq(2)
      expect(subject).to have_selector("a[href='##{repetition_tdc.html_id}']")
      row_ids.each.with_index(1) do |row_id, row_number|
        expect(subject).to have_selector("a[href='##{repetition_tdc.html_id(row_id)}']", text: "#{repetition_tdc.libelle} #{row_number}")
        expect(subject).to have_selector("a[href='##{section_in_repetition.html_id(row_id)}']")
      end
    end

    context 'when the repetition has no rows' do
      let(:types_de_champ) do
        [{ type: :repetition, mandatory: false, children: [{ type: :text }, { type: :header_section, level: 1 }] }]
      end
      let(:dossier) { create(:dossier, procedure:) }

      it 'lists the repetition but not its content' do
        expect(subject).to have_selector("a[href='##{repetition_tdc.html_id}']", count: 1)
      end
    end

    context 'when sections are hidden by a condition' do
      let(:procedure) { create(:procedure, types_de_champ_public: types_de_champ) }
      let(:types_de_champ) do
        [
          { type: :yes_no, stable_id: 42 },
          { type: :header_section, level: 1, libelle: 'visible section' },
          { type: :header_section, level: 1, libelle: 'hidden section', condition: ds_eq(champ_value(42), constant(true)) },
          { type: :repetition, mandatory: false, libelle: 'hidden repetition', condition: ds_eq(champ_value(42), constant(true)), children: [{ type: :text }] },
        ]
      end
      let(:dossier) { create(:dossier, procedure:) }

      it 'excludes hidden sections and repetitions from the summary' do
        expect(subject).to have_text('visible section')
        expect(subject).not_to have_text('hidden section')
        expect(subject).not_to have_text('hidden repetition')
      end
    end
  end

  context 'private' do
    let(:is_private) { true }
    it do
      types_de_champ_private.each { expect(subject).to have_selector("a[href='##{_1.html_id}']") }
    end
  end
end
