# frozen_string_literal: true

describe Migrations::NormalizeCommunesJob, type: :job do
  context 'when value is "", external_id is "", and code_departement is "undefined"' do
    let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
    let(:types_de_champ_public) { [{ type: :communes }] }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:champ) { dossier.project_champs_public.first }

    before { champ.update_columns(external_id: "", value: "", value_json: { code_departement: 'undefined', departement: 'undefined' }) }
    subject { described_class.perform_now([champ.champ_data.id]) }
    it 'empty the champs' do
      subject
      champ.reload
      expect(champ.code_postal).to be_nil
      expect(champ.code_departement).to be_nil
    end
  end
end
