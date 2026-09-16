# frozen_string_literal: true

describe Migrations::NormalizeCommunesJob, type: :job do
  context 'when value is "", external_id is "", and department_code is "undefined"' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
    let(:public_type_de_champs) { [{ type: :communes }] }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:champ) { dossier.champ_data.first }

    before { champ.update_columns(external_id: "", value: "", value_json: { department_code: 'undefined', departement: 'undefined' }) }
    subject { described_class.perform_now([champ.id]) }
    it 'empty the champs' do
      subject
      champ.reload
      expect(champ.postal_code).to be_nil
      expect(champ.department_code).to be_nil
    end
  end
end
