# frozen_string_literal: true

describe Columns::DossierLinkNumberColumn do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :dossier_link, libelle: 'Dossier lié' }]) }
  let(:column) { procedure.active_revision.type_de_champs.first.columns(procedure_id: procedure.id).first }
  let(:stable_id) { column.stable_id }

  def dossier_linked_to(value)
    create(:dossier, :en_construction, procedure:).tap { it.champ_data.first.update_columns(value:) }
  end

  describe '#sorted_ids' do
    let!(:ten) { dossier_linked_to('10') }
    let!(:nine) { dossier_linked_to('9') }
    let!(:hundred) { dossier_linked_to('100') }
    let(:numbered_ids) { [nine, ten, hundred].map(&:id) }
    let(:unnumbered_ids) do
      [
        dossier_linked_to(nil),
        dossier_linked_to(''),
        dossier_linked_to('abc'),
        create(:dossier, :en_construction, procedure:).tap { it.champ_data.where(stable_id:).delete_all },
      ].map(&:id)
    end
    let(:dossiers) { Dossier.where(id: numbered_ids + unnumbered_ids) }

    def sorted_ids(order) = column.sorted_ids(dossiers, order, count: dossiers.count)

    it 'sorts by number, the dossiers without number last ascending and first descending' do
      expect(sorted_ids('asc').take(3)).to eq(numbered_ids)
      expect(sorted_ids('asc').drop(3)).to match_array(unnumbered_ids)
      expect(sorted_ids('desc').take(4)).to match_array(unnumbered_ids)
      expect(sorted_ids('desc').drop(4)).to eq(numbered_ids.reverse)
    end
  end
end
