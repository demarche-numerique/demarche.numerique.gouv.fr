# frozen_string_literal: true

describe Columns::DossierLinkProcedureColumn do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :dossier_link }]) }
  let(:stable_id) { procedure.active_revision.public_root_type_de_champs.first.stable_id }
  let(:target_a) { create(:procedure, libelle: 'Bravo') }
  let(:target_b) { create(:procedure, libelle: 'Alpha') }
  let(:target_c) { create(:procedure, libelle: 'Charlie') }
  let(:limited_procedure_ids) { nil }
  let(:column_procedure_id) { procedure.id }
  let(:column) { build_column }
  let(:purged_id) { create(:procedure).tap(&:destroy!).id }
  let(:deleted_label) { I18n.t('activerecord.attributes.procedure_presentation.fields.dossier_link.deleted_procedure', id: purged_id) }

  def build_column
    described_class.new(procedure_id: column_procedure_id, label: 'label', stable_id:, tdc_type: 'dossier_link', displayable: true, mandatory: true, limited_procedure_ids:)
  end

  def link_dossier(target, state: :en_construction, on: procedure, **attributes)
    create(:dossier, state, procedure: on, **attributes).tap do |dossier|
      dossier.champ_data.first.update!(value: create(:dossier, :en_construction, procedure: target).id)
    end
  end

  it 'targets the procedure id of the champ' do
    expect(column.type).to eq(:enum)
    expect(column.jsonpath).to eq('$.procedure_id')
    expect(column.column_id).to eq("type_de_champ/#{stable_id}-$.procedure_id")
  end

  describe '#value' do
    let(:champ) { create(:dossier, procedure:).champ_data.first }

    subject { column.value(champ) }

    context 'when champ has value_json' do
      before { champ.update_columns(value_json: { procedure_id: 123 }) }

      it { is_expected.to eq('123') }
    end

    context 'when champ has no value_json' do
      it { is_expected.to be_nil }
    end
  end

  describe '#options_for_select' do
    context 'limited' do
      let(:limited_procedure_ids) { [target_b.id, target_a.id] }

      it 'lists the configured procedures in the configured order' do
        expect(column.options_for_select).to eq([[target_b.libelle, target_b.id.to_s], [target_a.libelle, target_a.id.to_s]])
      end

      context 'with a destroyed procedure' do
        let(:limited_procedure_ids) { [target_b.id, purged_id, target_a.id] }

        it 'keeps it in place with a replacement label' do
          expect(column.options_for_select).to eq([
            [target_b.libelle, target_b.id.to_s],
            [deleted_label, purged_id.to_s],
            [target_a.libelle, target_a.id.to_s],
          ])
        end

        it 'does not query champs' do
          link_dossier(target_c)
          limited_procedure_ids
          expect(count_queries(matching: /"champs"/) { column.options_for_select }).to eq(0)
        end
      end
    end

    context 'not limited' do
      before do
        link_dossier(target_a)
        link_dossier(target_b, state: :accepte)
        link_dossier(target_a)
        link_dossier(target_c, state: :brouillon)
        link_dossier(target_c, for_procedure_preview: true)
        link_dossier(target_c).champ_data.first.update_columns(stream: Dossier::USER_BUFFER_STREAM)
        link_dossier(target_c, on: create(:procedure, public_type_de_champs: [{ type: :dossier_link }])).champ_data.update_all(stable_id:)
      end

      it 'lists the procedures linked by submitted dossiers, sorted by title' do
        expect(column.options_for_select).to eq([[target_b.libelle, target_b.id.to_s], [target_a.libelle, target_a.id.to_s]])
      end

      it 'loads the titles in one query' do
        link_dossier(target_c)
        column

        count = count_queries(matching: /"procedures"/) do
          expect(column.options_for_select.map(&:last)).to eq([target_b, target_a, target_c].map { it.id.to_s })
        end
        expect(count).to eq(1)
      end

      context 'with a cache store', :caching do
        it 'queries the observed procedures once' do
          count = count_queries(matching: /"champs"/) do
            2.times { expect(build_column.options_for_select.map(&:last)).to eq([target_b.id.to_s, target_a.id.to_s]) }
          end
          expect(count).to eq(1)
        end
      end

      context 'with accented and lowercase titles' do
        let(:target_a) { create(:procedure, libelle: 'Zones') }
        let(:target_b) { create(:procedure, libelle: 'Écoles') }
        let(:target_c) { create(:procedure, libelle: 'ateliers') }

        it 'sorts the titles regardless of accents and case' do
          link_dossier(target_c)

          expect(column.options_for_select.map(&:first)).to eq(['ateliers', 'Écoles', 'Zones'])
        end
      end

      context 'without procedure' do
        let(:column_procedure_id) { nil }

        it 'is empty and does not query champs' do
          expect(count_queries(matching: /"champs"/) { expect(column.options_for_select).to eq([]) }).to eq(0)
        end

        it 'does not touch the cache', :caching do
          expect(Rails.cache).not_to receive(:fetch)
          expect(column.options_for_select).to eq([])
        end
      end
    end
  end

  describe '#label_for_value' do
    it 'returns the current title' do
      target_a.update!(libelle: 'Renommée')
      expect(column.label_for_value(target_a.id.to_s)).to eq('Renommée')
    end

    it 'returns the title of a discarded procedure' do
      target_a.discard!
      expect(column.label_for_value(target_a.id.to_s)).to eq(target_a.libelle)
    end

    it 'returns a replacement label for a destroyed procedure' do
      expect(column.label_for_value(purged_id.to_s)).to eq(deleted_label)
    end

    context 'limited' do
      let(:limited_procedure_ids) { [target_a.id] }

      it 'returns the title of a procedure outside the configured ones' do
        expect(column.label_for_value(target_b.id.to_s)).to eq(target_b.libelle)
      end
    end

    it 'returns the not filled label' do
      expect(column.label_for_value(Column::NOT_FILLED_VALUE)).to eq(I18n.t('activerecord.attributes.type_de_champ.not_filled'))
    end

    it 'reads the value in base 10' do
      expect(column.label_for_value("0#{target_a.id.to_s(8)}")).not_to eq(target_a.libelle)
    end

    it 'returns nil for a blank value' do
      expect(column.label_for_value(nil)).to be_nil
      expect(column.label_for_value('')).to be_nil
    end

    it 'loads a title once per request' do
      target_a
      stable_id
      count = count_queries(matching: /"procedures"/) do
        3.times { expect(build_column.label_for_value(target_a.id.to_s)).to eq(target_a.libelle) }
      end
      expect(count).to eq(1)
    end

    it 'does not query champs' do
      targets = [target_a, target_b, target_c]
      targets.each { link_dossier(it) }

      count = count_queries(matching: /"champs"/) do
        targets.each { expect(column.label_for_value(it.id.to_s)).to eq(it.libelle) }
      end
      expect(count).to eq(0)
    end

    context 'limited with a dossier linked outside the configured procedures' do
      let(:limited_procedure_ids) { [target_a.id] }

      it 'loads the configured titles together and the outside title alone, without querying champs' do
        link_dossier(target_b)
        column

        procedures_count = 0
        champs_count = count_queries(matching: /"champs"/) do
          procedures_count = count_queries(matching: /"procedures"/) do
            [target_a, target_b].each { expect(column.label_for_value(it.id.to_s)).to eq(it.libelle) }
          end
        end
        expect(procedures_count).to be <= 2
        expect(champs_count).to eq(0)
      end
    end
  end

  describe '#preload' do
    let(:targets) { [target_a, target_b, target_c] }
    let(:linked_champs) { targets.map { link_dossier(it).champ_data.first } }
    let(:without_link) { create(:dossier, :en_construction, procedure:).champ_data.first }
    let(:to_purged) { create(:dossier, :en_construction, procedure:).champ_data.first.tap { it.update_columns(value_json: { procedure_id: purged_id }) } }
    let(:other_target) { create(:procedure) }
    let(:other_stable_id_champ) { ChampData.new(stable_id: stable_id.succ, value_json: { 'procedure_id' => other_target.id }) }
    let(:champs) { linked_champs + [without_link, to_purged, other_stable_id_champ] }

    before { [champs, deleted_label, column] }

    it 'loads the titles of the champs in one query' do
      procedures_count = 0
      champs_count = count_queries(matching: /"champs"/) do
        procedures_count = count_queries(matching: /"procedures"/) { column.preload(champs) }
      end
      expect(procedures_count).to eq(1)
      expect(champs_count).to eq(0)
    end

    it 'resolves the titles without any further query' do
      column.preload(champs)

      count = count_queries(matching: /"procedures"|"champs"/) do
        column.preload(champs)
        targets.each { expect(column.label_for_value(it.id.to_s)).to eq(it.libelle) }
        expect(column.label_for_value(purged_id.to_s)).to eq(deleted_label)
      end
      expect(count).to eq(0)
    end

    it 'does not query without champs' do
      expect(count_queries { column.preload([without_link]) }).to eq(0)
    end

    it 'ignores the champs of other stable ids' do
      column.preload(champs)

      count = count_queries(matching: /"procedures"/) do
        expect(column.label_for_value(other_target.id.to_s)).to eq(other_target.libelle)
      end
      expect(count).to eq(1)
    end
  end

  describe '#sorted_ids' do
    let(:zebre) { create(:procedure, libelle: 'Zèbre') }
    let(:mike) { create(:procedure, libelle: 'Mike') }
    let(:alpha) { create(:procedure, libelle: 'Alpha') }
    let!(:linked_to_zebre) { link_dossier(zebre) }
    let!(:linked_to_mike) { link_dossier(mike).tap { mike.discard! } }
    let!(:linked_to_alpha) { link_dossier(alpha) }
    let(:without_champ) { create(:dossier, :en_construction, procedure:).tap { it.champ_data.where(stable_id:).delete_all } }
    let(:without_link) { create(:dossier, :en_construction, procedure:) }
    let(:unresolved) { create(:dossier, :en_construction, procedure:).tap { it.champ_data.first.update_columns(value: '0', value_json: nil) } }
    let(:to_purged) { create(:dossier, :en_construction, procedure:).tap { it.champ_data.first.update_columns(value_json: { procedure_id: purged_id }) } }
    let(:titled_ids) { [linked_to_alpha, linked_to_mike, linked_to_zebre].map(&:id) }
    let(:untitled_ids) { [without_champ, without_link, unresolved, to_purged].map(&:id) }
    let(:dossiers) { Dossier.where(id: titled_ids + untitled_ids) }

    def sorted_ids(order) = column.sorted_ids(dossiers, order, count: dossiers.count)

    def linked_number(dossier) = dossier.champ_data.first.value.to_i

    it 'sorts by title ascending, the dossiers without title last' do
      expect(linked_number(linked_to_zebre)).to be < linked_number(linked_to_mike)
      expect(linked_number(linked_to_mike)).to be < linked_number(linked_to_alpha)
      expect(without_champ.champ_data.where(stable_id:)).to be_empty

      ids = sorted_ids('asc')

      expect(ids.take(3)).to eq(titled_ids)
      expect(ids.drop(3)).to match_array(untitled_ids)
    end

    it 'sorts by title descending, the dossiers without title first' do
      ids = sorted_ids('desc')

      expect(ids.take(4)).to match_array(untitled_ids)
      expect(ids.drop(4)).to eq(titled_ids.reverse)
    end
  end

  describe '#filtered_ids' do
    let(:dossier_1) { create(:dossier, :en_construction, procedure:) }
    let(:dossier_2) { create(:dossier, :en_construction, procedure:) }
    let(:dossiers) { Dossier.where(id: [dossier_1.id, dossier_2.id]) }

    before do
      dossier_1.champ_data.first.update_columns(value_json: { procedure_id: 123 })
      dossier_2.champ_data.first.update_columns(value_json: { procedure_id: 1234 })
    end

    def filtered_ids(value) = column.filtered_ids(dossiers, { operator: 'match', value: })

    it 'matches the id exactly' do
      expect(filtered_ids(['123'])).to eq([dossier_1.id])
    end

    it 'matches any of the ids' do
      expect(filtered_ids(['123', '1234'])).to match_array([dossier_1.id, dossier_2.id])
    end

    it 'ignores values that are not ids' do
      expect(filtered_ids(['abc'])).to match_array([dossier_1.id, dossier_2.id])
      expect(filtered_ids([''])).to match_array([dossier_1.id, dossier_2.id])
    end

    it 'does not read the values as hexadecimal' do
      expect(filtered_ids(['0x7b'])).to match_array([dossier_1.id, dossier_2.id])
    end
  end
end
