# frozen_string_literal: true

describe Columns::DossierLinkSubmissionDateColumn do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :dossier_link }]) }
  let(:stable_id) { procedure.active_revision.public_root_type_de_champs.first.stable_id }
  let(:column) { described_class.new(procedure_id: procedure.id, label: 'label', stable_id:, tdc_type: 'dossier_link', displayable: true, mandatory: true) }
  let(:may) { dossier_submitted_on('2026-05-06') }
  let(:march) { dossier_submitted_on('2026-03-04') }
  let(:without_date) { dossier_submitted_on(nil) }

  def dossier_submitted_on(submitted_on)
    create(:dossier, :en_construction, procedure:).tap do |dossier|
      dossier.champ_data.first.update_columns(value: '1', value_json: { procedure_id: 1, submitted_on: }.compact)
    end
  end

  it 'targets the submission date of the champ' do
    expect(column.type).to eq(:date)
    expect(column.jsonpath).to eq('$.submitted_on')
    expect(column.column_id).to eq("type_de_champ/#{stable_id}-$.submitted_on")
  end

  describe '#value' do
    it 'returns the stored date' do
      expect(column.value(dossier_submitted_on('2026-03-04').champ_data.first)).to eq(Date.new(2026, 3, 4))
    end

    it 'returns nil without a stored date' do
      expect(column.value(dossier_submitted_on(nil).champ_data.first)).to be_nil
    end
  end

  describe '#filtered_ids' do
    let(:dossiers) { Dossier.where(id: [may, march, without_date].map(&:id)) }

    def filtered_ids(operator, *value) = column.filtered_ids(dossiers, { operator:, value: })

    it 'filters on the stored date' do
      expect(filtered_ids('before', '2026-04-01')).to eq([march.id])
      expect(filtered_ids('after', '2026-04-01')).to eq([may.id])
      expect(filtered_ids('between', '2026-03-04', '2026-05-05')).to eq([march.id])
      expect(filtered_ids('between', '2026-03-05', '2026-05-06')).to eq([may.id])
    end
  end

  describe '#sorted_ids' do
    let(:without_champ) { create(:dossier, :en_construction, procedure:).tap { it.champ_data.where(stable_id:).delete_all } }
    let(:dossiers) { Dossier.where(id: [may, march, without_date, without_champ].map(&:id)) }

    def sorted_ids(order) = column.sorted_ids(dossiers, order, count: dossiers.count)

    it 'sorts by date, the dossiers without date last ascending and first descending' do
      expect(sorted_ids('asc').take(2)).to eq([march.id, may.id])
      expect(sorted_ids('asc').drop(2)).to contain_exactly(without_date.id, without_champ.id)
      expect(sorted_ids('desc').take(2)).to contain_exactly(without_date.id, without_champ.id)
      expect(sorted_ids('desc').drop(2)).to eq([may.id, march.id])
    end
  end
end
