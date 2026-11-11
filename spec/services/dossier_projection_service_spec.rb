# frozen_string_literal: true

describe DossierProjectionService do
  describe '#project' do
    subject { described_class.project(dossiers_ids, columns) }

    let(:procedure) { create(:procedure, public_type_de_champs:) }
    let(:public_type_de_champs) do
      [
        { type: :text, libelle: 'texte' },
        { type: :integer_number, libelle: 'nombre entier' },
      ]
    end
    let(:dossiers) { create_list(:dossier, 3, procedure:) }
    let(:dossiers_ids) { dossiers.take(2).map(&:id) }
    let(:text_column) { procedure.find_column(label: 'texte') }
    let(:columns) { [text_column] }

    it do
      projections = subject

      expect(projections.size).to eq(2)

      projection = projections.first
      expect(projection.dossier).to eq(dossiers.first)

      # only load the champ_data required for the columns
      expect(projection.champ_data.keys).to eq([text_column.stable_id])
    end

    context 'with the linked dossier columns' do
      let(:public_type_de_champs) { [{ type: :dossier_link, libelle: 'lien' }, { type: :text, libelle: 'texte' }] }
      let(:link_column) { procedure.find_column(label: 'lien – Intitulé de la démarche') }
      let(:link_columns) { ['lien – N° dossier', 'lien – Date de dépôt du dossier', 'lien – Intitulé de la démarche', 'lien – Service porteur de la démarche'].map { procedure.find_column(label: it) } }
      let(:targets) { create_list(:procedure, 2) }

      before do
        dossiers.take(2).zip(targets).each do |dossier, target|
          dossier.champ_data.find { it.stable_id == link_column.stable_id }.update_columns(value: '42', value_json: { procedure_id: target.id, submitted_on: '2026-03-04' })
        end
        text_column
        link_columns
      end

      it 'loads the titles and the services of the projected dossiers without querying champs again' do
        text_champs_count = count_queries(matching: /"champs"/) { described_class.project(dossiers_ids, [text_column]) }
        text_procedures_count = count_queries(matching: /"procedures"/) { described_class.project(dossiers_ids, [text_column]) }
        projections = nil
        procedures_count = 0
        link_champs_count = count_queries(matching: /"champs"/) do
          procedures_count = count_queries(matching: /"procedures"/) { projections = described_class.project(dossiers_ids, link_columns) }
        end
        expect(link_champs_count).to eq(text_champs_count)
        expect(procedures_count).to eq(text_procedures_count + 1)

        count = count_queries(matching: /"procedures"|"champs"/) do
          projections.zip(targets).each do |projection, target|
            champ = projection.champ_data.fetch(link_column.stable_id)
            expect(link_columns.map { it.value(champ) }).to eq(['42', Date.new(2026, 3, 4), target.id.to_s, target.organisation_name])
            expect(link_column.label_for_value(target.id.to_s)).to eq(target.libelle)
          end
        end
        expect(count).to eq(0)
      end
    end

    context 'without champ columns' do
      let(:columns) { [procedure.dossier_id_column] }

      it { expect(subject.first.champ_data).to eq({}) }
    end
  end
end
