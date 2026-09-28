# frozen_string_literal: true

describe LegacyExportTemplate do
  let(:procedure) { create(:procedure, :published, for_individual:, ask_birthday: true, public_type_de_champs:) }
  let(:for_individual) { true }
  let(:public_type_de_champs) do
    [
      { type: :text, libelle: 'Texte', stable_id: 1 },
      { type: :checkbox, libelle: 'Case', stable_id: 2 },
      { type: :communes, libelle: 'Commune', stable_id: 3 },
      { type: :repetition, libelle: 'Bloc', stable_id: 4, children: [{ type: :integer_number, libelle: 'Nombre', stable_id: 5 }] },
    ]
  end
  let(:kind) { :xlsx }

  subject(:template) { described_class.new(procedure:, kind:) }

  describe '#dossier_exported_columns' do
    let(:libelles) { template.dossier_exported_columns.map(&:libelle) }

    it 'lists the historical columns of a procedure for individuals' do
      expect(libelles).to eq([
        'ID', 'Email', 'FranceConnect ?',
        'Civilité', 'Nom', 'Prénom', 'Dépôt pour un tiers', 'Nom du mandataire', 'Prénom du mandataire', 'Date de naissance',
        'À archiver', 'État du dossier', 'Dernière mise à jour le', 'Dernière mise à jour du dossier le', 'Déposé le', 'Passé en instruction le',
        'Traité le', 'Motivation de la décision', 'Instructeurs',
      ])
    end

    it 'keeps the id and the booleans as text, the rest on catalogue columns' do
      by_libelle = template.dossier_exported_columns.index_by(&:libelle)

      expect(by_libelle.values_at('ID', 'FranceConnect ?', 'Dépôt pour un tiers', 'À archiver').map(&:column)).to all(be_a(Columns::LegacyColumn))
      expect(by_libelle['Email'].column).to be_a(Columns::DossierColumn)
      expect(by_libelle['Email'].column).not_to be_a(Columns::LegacyColumn)
      expect(by_libelle['Date de naissance'].column).to have_attributes(table: 'individual', column: 'birthdate', type: :date)
    end

    it 'labels the states as the historical export did, including the ones the filters leave out' do
      state = template.dossier_exported_columns.find { it.libelle == 'État du dossier' }.column

      expect(state.label_for_value('brouillon')).to eq('Brouillon')
      expect(state.label_for_value('en_construction')).to eq(Dossier.human_attribute_name('state.en_construction'))
    end

    context 'for a procedure of entreprises' do
      let(:for_individual) { false }

      it 'only has the raison sociale on the Dossiers sheet' do
        expect(libelles).to include('Entreprise raison sociale')
        expect(libelles).not_to include('Établissement SIRET', 'Civilité')
      end

      context 'as csv' do
        let(:kind) { :csv }

        it 'inlines the établissement columns' do
          expect(libelles).to include('Établissement SIRET', 'Établissement NAF', 'Association date de publication')
        end
      end
    end

    context 'with routing' do
      before { procedure.update!(routing_enabled: true) }

      it 'ends with the groupe instructeur' do
        expect(libelles.last).to eq('Groupe instructeur')
      end
    end
  end

  describe '#columns_for_stable_id' do
    def described(exported_columns) = exported_columns.map { [it.libelle, it.column.class] }

    it 'pairs a type de champ with its catalogue column or a legacy one, under the historical libellé' do
      expect(described(template.columns_for_stable_id(1))).to eq([['Texte', Columns::ChampColumn]])
      expect(described(template.columns_for_stable_id(2))).to eq([['Case', Columns::LegacyColumn]])
      expect(described(template.columns_for_stable_id(3))).to eq([
        ['Commune', Columns::LegacyColumn],
        ['Commune (Code INSEE)', Columns::JSONPathColumn],
        ['Commune (Département)', Columns::JSONPathColumn],
      ])
    end

    it 'indexes the children of a repetition, not the repetition itself' do
      expect(template.columns_for_stable_id(4)).to be_empty
      expect(template.columns_for_stable_id(5).map { [it.libelle, it.column.class, it.column.type] }).to eq([['Nombre', Columns::LegacyColumn, :integer]])
    end

    it 'has nothing for an unknown stable_id' do
      expect(template.columns_for_stable_id(999)).to eq([])
    end
  end
end
