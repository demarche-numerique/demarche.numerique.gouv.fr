# frozen_string_literal: true

describe 'dossiers/dossier_vide', type: :view do
  let(:procedure) { create(:procedure, :with_all_champs) }

  before do
    assign(:procedure, procedure)
    assign(:revision, procedure.draft_revision)
  end

  subject { render }

  it 'renders a PDF document with empty fields' do
    subject
    expect(rendered).to be_present
  end

  context 'with a repetition containing header sections' do
    let(:procedure) do
      create(:procedure, types_de_champ_public: [
        {
          type: :repetition, libelle: 'rep', children: [
            { type: :header_section, level: 1, libelle: 'rs1' },
            { type: :text, libelle: 'rt1' },
          ],
        },
      ])
    end

    it 'renders the champs nested in the sections' do
      allow(view).to receive(:empty_format_in_2_lines).and_call_original
      subject
      expect(view).to have_received(:empty_format_in_2_lines).with(anything, having_attributes(libelle: 'rt1'), any_args).thrice
    end
  end
end
