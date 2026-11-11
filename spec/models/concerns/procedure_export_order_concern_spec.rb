# frozen_string_literal: true

describe ProcedureExportOrderConcern do
  let(:procedure) do
    create(:procedure, :published, public_type_de_champs: [
      { type: :repetition, libelle: 'rep1', children: [{ libelle: 'r1' }] },
      { type: :text, libelle: 'a' },
      { type: :text, libelle: 'b' },
      { type: :text, libelle: 'c' },
      { type: :text, libelle: 'd' },
      { type: :repetition, libelle: 'rep2', children: [{ libelle: 's1' }, { libelle: 's2' }, { libelle: 's3' }] },
    ])
  end
  let(:legacy_export_order) { false }

  def stable_id(libelle) = TypeDeChamp.where(id: procedure.revisions.joins(:revision_type_de_champs).select(:type_de_champ_id)).find_by!(libelle:).stable_id
  def libelles(type_de_champs) = type_de_champs.map(&:libelle)

  def remove_and_publish(*libelles)
    libelles.each { procedure.draft_revision.remove_type_de_champ(stable_id(it)) }
    procedure.publish_revision!(procedure.administrateurs.first)
    procedure.update!(legacy_export_order:)
  end

  subject(:exported) { Procedure.find(procedure.id) }

  it 'is not kept by a new procedure' do
    expect(procedure).not_to be_legacy_export_order
  end

  context 'with the legacy export order the same as the form' do
    let(:legacy_export_order) { true }

    before { remove_and_publish('d') }

    it { is_expected.not_to be_legacy_export_order_differs }
  end

  context 'once a type de champ was removed' do
    before { remove_and_publish('b', 's1') }

    it 'lays it at the end of its sheet' do
      rep2 = exported.repetition_type_de_champs_for_procedure_export.last
      expect(libelles(exported.type_de_champs_for_procedure_export)).to eq(['a', 'c', 'd', 'b'])
      expect(libelles(exported.repetition_children_for_procedure_export(rep2))).to eq(['s2', 's3', 's1'])
    end

    context 'with the legacy export order' do
      let(:legacy_export_order) { true }

      it 'keeps it at its last position' do
        rep2 = exported.repetition_type_de_champs_for_procedure_export.last
        expect(libelles(exported.type_de_champs_for_procedure_export)).to eq(['a', 'c', 'b', 'd'])
        expect(libelles(exported.repetition_children_for_procedure_export(rep2))).to eq(['s2', 's1', 's3'])
        expect(exported).to be_legacy_export_order_differs
      end
    end
  end

  context 'once a repetition was removed' do
    before { remove_and_publish('rep1') }

    it 'lays its sheet last' do
      expect(libelles(exported.repetition_type_de_champs_for_procedure_export)).to eq(['rep2', 'rep1'])
    end

    context 'with the legacy export order' do
      let(:legacy_export_order) { true }

      it 'keeps its sheet at its last position' do
        expect(libelles(exported.repetition_type_de_champs_for_procedure_export)).to eq(['rep1', 'rep2'])
        expect(exported).to be_legacy_export_order_differs
      end
    end
  end
end
