# frozen_string_literal: true

describe Columns::DossierLinkProcedureAgencyColumn do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :dossier_link }]) }
  let(:stable_id) { procedure.active_revision.public_root_type_de_champs.first.stable_id }
  let(:column) { described_class.new(procedure_id: procedure.id, label: 'label', stable_id:, tdc_type: 'dossier_link', displayable: true, mandatory: true) }
  let(:target) { create(:procedure, service: create(:service, nom: 'Mairie de Lyon')) }
  let(:without_service) { create(:procedure, service: nil, organisation: 'Préfecture du Rhône') }
  let(:purged_id) { create(:procedure).tap(&:destroy!).id }

  def dossier_linked_to(procedure_id)
    create(:dossier, :en_construction, procedure:).tap do |dossier|
      dossier.champ_data.first.update_columns(value: '1', value_json: procedure_id && { procedure_id: })
    end
  end

  def champ_linked_to(procedure_id) = dossier_linked_to(procedure_id).champ_data.first

  it 'is a displayable text column that cannot be filtered' do
    expect(column.type).to eq(:text)
    expect(column.displayable).to be(true)
    expect(column.filterable).to be(false)
    expect(column.column_id).to eq("type_de_champ/#{stable_id}.procedure_agency")
  end

  describe '#value' do
    it 'returns the current name of the service' do
      champ = champ_linked_to(target.id)
      target.service.update!(nom: 'Métropole de Lyon')

      expect(column.value(champ)).to eq('Métropole de Lyon')
    end

    it 'returns the organisation of a procedure without service' do
      expect(column.value(champ_linked_to(without_service.id))).to eq('Préfecture du Rhône')
    end

    it 'returns the service of a discarded procedure' do
      target.discard!
      expect(column.value(champ_linked_to(target.id))).to eq('Mairie de Lyon')
    end

    it 'returns nil for a destroyed procedure or without link' do
      expect(column.value(champ_linked_to(purged_id))).to be_nil
      expect(column.value(champ_linked_to(nil))).to be_nil
    end
  end

  describe '#preload' do
    let(:title_column) { Columns::DossierLinkProcedureColumn.new(procedure_id: procedure.id, label: 'label', stable_id:, tdc_type: 'dossier_link', displayable: true, mandatory: true, limited_procedure_ids: nil) }
    let(:champs) { [target, without_service].map { champ_linked_to(it.id) } + [champ_linked_to(purged_id), champ_linked_to(nil)] }

    before { [champs, column, title_column] }

    it 'loads the titles and the services of a page in one query' do
      procedures_count = 0
      champs_count = count_queries(matching: /"champs"/) do
        procedures_count = count_queries(matching: /"procedures"/) do
          [title_column, column].each { it.preload(champs) }
          expect(champs.map { column.value(it) }).to eq(['Mairie de Lyon', 'Préfecture du Rhône', nil, nil])
          expect(champs.map { title_column.label_for_value(title_column.value(it)) }.first(2)).to eq([target.libelle, without_service.libelle])
        end
      end
      expect(procedures_count).to eq(1)
      expect(champs_count).to eq(0)
    end
  end

  describe '#sorted_ids' do
    let(:zebre) { create(:procedure, service: create(:service, nom: 'Zèbre')) }
    let(:alpha) { create(:procedure, service: nil, organisation: 'Alpha') }
    let(:mike) { create(:procedure, service: create(:service, nom: 'Mike')).tap(&:discard!) }
    let!(:linked_to_zebre) { dossier_linked_to(zebre.id) }
    let!(:linked_to_mike) { dossier_linked_to(mike.id) }
    let!(:linked_to_alpha) { dossier_linked_to(alpha.id) }
    let(:untitled_ids) do
      [
        dossier_linked_to(purged_id),
        dossier_linked_to(nil),
        create(:dossier, :en_construction, procedure:).tap { it.champ_data.where(stable_id:).delete_all },
      ].map(&:id)
    end
    let(:named_ids) { [linked_to_alpha, linked_to_mike, linked_to_zebre].map(&:id) }
    let(:dossiers) { Dossier.where(id: named_ids + untitled_ids) }

    def sorted_ids(order) = column.sorted_ids(dossiers, order, count: dossiers.count)

    it 'sorts by service name, the dossiers without service last ascending and first descending' do
      expect(sorted_ids('asc').take(3)).to eq(named_ids)
      expect(sorted_ids('asc').drop(3)).to match_array(untitled_ids)
      expect(sorted_ids('desc').take(3)).to match_array(untitled_ids)
      expect(sorted_ids('desc').drop(3)).to eq(named_ids.reverse)
    end
  end
end
