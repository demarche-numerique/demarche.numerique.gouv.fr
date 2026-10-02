# frozen_string_literal: true

describe ColumnsConcern do
  let(:procedure_id) { procedure.id }

  describe '#find_column' do
    let(:public_type_de_champs) do
      [
        { type: :linked_drop_down_list, libelle: 'linked' },
        { type: :address, libelle: 'address' },
      ]
    end
    let(:procedure) { create(:procedure, public_type_de_champs:) }
    let(:procedure_id) { procedure.id }
    let(:notifications_column) { procedure.notifications_column }

    it 'works' do
      label = notifications_column.label
      expect(procedure.find_column(label:)).to eq(notifications_column)

      h_id = notifications_column.h_id
      expect(procedure.find_column(h_id:)).to eq(notifications_column)

      unknwon = 'unknown'
      expect { procedure.find_column(h_id: unknwon) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'when the column_id is a old linked drop down list id' do
      let(:linked_drop_down_column) { procedure.find_column(label: 'linked') }
      let(:linked_tdc) { procedure.active_revision.type_de_champs.find { _1.type_champ == 'linked_drop_down_list' } }

      it do
        column_id = "type_de_champ/#{linked_tdc.stable_id}->value"

        h_id = { procedure_id:, column_id: }
        expect(procedure.find_column(h_id:)).to eq(linked_drop_down_column)
      end
    end

    context 'when the colum_id is an old department column id' do
      let(:department_column) { procedure.find_column(label: "address – Département") }
      let(:address_tdc) { procedure.active_revision.type_de_champs.find { _1.type_champ == 'address' } }

      it do
        column_id = "type_de_champ/#{address_tdc.stable_id}-$.departement_code"

        h_id = { procedure_id:, column_id: }
        expect(procedure.find_column(h_id:)).to eq(department_column)
      end
    end

    context 'when the column_id is an old naf column' do
      let(:code_naf_column) { procedure.find_column(label: "Code NAF") }

      it do
        column_id = "etablissement/naf"

        h_id = { procedure_id:, column_id: }
        expect(procedure.find_column(h_id:)).to eq(code_naf_column)
      end
    end

    xcontext 'when the column lives only in the draft revision' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :integer_number }]) }
      let(:referentiel) { create(:csv_referentiel, :with_items) }
      let(:integer_tdc) { procedure.draft_revision.type_de_champs.first }
      let(:draft_tdc) do
        procedure.draft_revision.add_type_de_champ(
          type_champ: 'drop_down_list',
          libelle: 'liste csv',
          drop_down_mode: 'advanced',
          referentiel_id: referentiel.id,
          after_stable_id: integer_tdc.stable_id
        )
      end
      let(:draft_column) { draft_tdc.columns(procedure_id: procedure.id).first }

      it 'falls back to the draft revision columns' do
        expect(procedure.find_column(h_id: draft_column.h_id)).to eq(draft_column)
      end
    end
  end

  describe "#columns" do
    subject { procedure.columns }

    context 'when the procedure can have a SIRET number' do
      let(:procedure) { create(:procedure, public_type_de_champs:, private_type_de_champs:) }
      let(:tdc_1) { procedure.active_revision.public_root_type_de_champs[0] }
      let(:tdc_2) { procedure.active_revision.public_root_type_de_champs[1] }
      let(:tdc_private_1) { procedure.active_revision.private_root_type_de_champs[0] }
      let(:tdc_private_2) { procedure.active_revision.private_root_type_de_champs[1] }
      let(:expected) {
        [
          { label: 'Dossier ID', table: 'self', column: 'id', displayable: true, type: :number, filterable: true },
          { label: 'notifications', table: 'notifications', column: 'notifications', displayable: true, type: :text, filterable: false },
          { label: 'Date de création', table: 'self', column: 'created_at', displayable: true, type: :date, filterable: true },
          { label: 'Mis à jour le', table: 'self', column: 'updated_at', displayable: true, type: :date, filterable: true },
          { label: 'Date de dépôt', table: 'self', column: 'depose_at', displayable: true, type: :date, filterable: true },
          { label: 'En construction le', table: 'self', column: 'en_construction_at', displayable: true, type: :date, filterable: true },
          { label: 'En instruction le', table: 'self', column: 'en_instruction_at', displayable: true, type: :date, filterable: true },
          { label: 'Terminé le', table: 'self', column: 'processed_at', displayable: true, type: :date, filterable: true },
          { label: "Dernier évènement depuis", table: "self", column: "updated_since", displayable: false, type: :date, filterable: true },
          { label: "Déposé depuis", table: "self", column: "depose_since", displayable: false, type: :date, filterable: true },
          { label: "En construction depuis", table: "self", column: "en_construction_since", displayable: false, type: :date, filterable: true },
          { label: "En instruction depuis", table: "self", column: "en_instruction_since", displayable: false, type: :date, filterable: true },
          { label: "Traité depuis", table: "self", column: "processed_since", displayable: false, type: :date, filterable: true },
          { label: "Statut", table: "self", column: "state", displayable: false, type: :enum, filterable: true },
          { label: "Archivé", table: "self", column: "archived", displayable: false, type: :text, filterable: false },
          { label: "Motivation de la décision", table: "self", column: "motivation", displayable: false, type: :text, filterable: false },
          { label: "Date de dernière modification (usager)", table: "self", column: "last_champ_updated_at", displayable: false, type: :text, filterable: false },
          { label: 'Demandeur', table: 'user', column: 'email', displayable: true, type: :text, filterable: true },
          { label: 'Adresse électronique instructeur', table: 'followers_instructeurs', column: 'email', displayable: true, type: :text, filterable: true },
          { label: 'Groupe instructeur', table: 'groupe_instructeur', column: 'id', displayable: true, type: :enum, filterable: true },
          { label: 'Avis oui/non', table: 'avis', column: 'question_answer', displayable: true, type: :text, filterable: false },
          { label: 'France connecté ?', table: 'self', column: 'user_from_france_connect?', displayable: false, type: :text, filterable: false },
          { label: "Labels", table: "dossier_labels", column: "label_id", displayable: true, filterable: true },
          { label: "Notifications sur le dossier", table: "dossier_notifications", column: "notification_type", displayable: false, filterable: true },
          { label: 'SIREN', table: 'etablissement', column: 'entreprise_siren', displayable: true, type: :text, filterable: true },
          { label: 'Forme juridique', table: 'etablissement', column: 'entreprise_forme_juridique', displayable: true, type: :text, filterable: true },
          { label: 'Nom commercial', table: 'etablissement', column: 'entreprise_nom_commercial', displayable: true, type: :text, filterable: true },
          { label: 'Raison sociale', table: 'etablissement', column: 'entreprise_raison_sociale', displayable: true, type: :text, filterable: true },
          { label: 'SIRET siège social', table: 'etablissement', column: 'entreprise_siret_siege_social', displayable: true, type: :text, filterable: true },
          { label: 'Date de création', table: 'etablissement', column: 'entreprise_date_creation', displayable: true, type: :date, filterable: true },
          { label: 'SIRET', table: 'etablissement', column: 'siret', displayable: true, type: :text, filterable: true },
          { label: 'Libellé NAF', table: 'etablissement', column: 'libelle_naf', displayable: true, type: :text, filterable: true },
          { label: 'Libellé NAF 2025', table: 'etablissement', column: 'libelle_naf_2025', displayable: true, type: :text, filterable: true },
          { label: 'Code postal', table: 'etablissement', column: 'code_postal', displayable: true, type: :text, filterable: true },
          { label: tdc_1.libelle, table: 'type_de_champ', column: tdc_1.stable_id.to_s, displayable: true, type: :text, filterable: true },
          { label: tdc_2.libelle, table: 'type_de_champ', column: tdc_2.stable_id.to_s, displayable: true, type: :text, filterable: true },
          { label: tdc_private_1.libelle, table: 'type_de_champ', column: tdc_private_1.stable_id.to_s, displayable: true, type: :text, filterable: true },
          { label: tdc_private_2.libelle, table: 'type_de_champ', column: tdc_private_2.stable_id.to_s, displayable: true, type: :text, filterable: true },
        ].map { Column.new(**_1.merge(procedure_id:)) }
      }

      context 'with explication/header_sections' do
        let(:public_type_de_champs) { Array.new(4) { { type: :text } } }
        let(:private_type_de_champs) { Array.new(4) { { type: :text } } }
        before do
          procedure.active_revision.public_root_type_de_champs[2].update_attribute(:type_champ, TypeDeChamp.type_champs.fetch(:header_section))
          procedure.active_revision.public_root_type_de_champs[3].update_attribute(:type_champ, TypeDeChamp.type_champs.fetch(:explication))
          procedure.active_revision.private_root_type_de_champs[2].update_attribute(:type_champ, TypeDeChamp.type_champs.fetch(:header_section))
          procedure.active_revision.private_root_type_de_champs[3].update_attribute(:type_champ, TypeDeChamp.type_champs.fetch(:explication))
        end

        it {
          expected.each do |expected|
            expect(subject).to include(expected)
          end
        }
      end

      context 'with rna' do
        let(:public_type_de_champs) { [{ type: :rna, libelle: 'RNA' }] }
        let(:private_type_de_champs) { [] }
        it { expect(subject.map(&:label)).to include('RNA – Commune') }
      end

      context 'with linked drop down list' do
        let(:public_type_de_champs) { [{ type: :linked_drop_down_list, libelle: 'linked' }] }
        let(:private_type_de_champs) { [] }
        it {
          expect(subject.map(&:label)).to include('linked (Primaire)')
          expect(subject.map(&:label)).to include('linked (Secondaire)')
        }
      end

      context 'with drop down list with csv referentiel' do
        let(:public_type_de_champs) { [{ type: :drop_down_list, libelle: 'liste csv', drop_down_mode: 'advanced', referentiel: }] }
        let(:referentiel) { create(:csv_referentiel, :with_items) }
        let(:private_type_de_champs) { [] }
        it {
          expect(subject.map(&:label)).to include('liste csv')
          expect(subject.map(&:label)).to include('liste csv – Référentiel calorie (kcal)')
          expect(subject.map(&:label)).to include('liste csv – Référentiel poids (g)')
        }
      end
    end

    context 'when the procedure is for individuals' do
      let(:name_field) { Column.new(procedure_id:, label: "Prénom", table: "individual", column: "prenom", displayable: true, type: :text, filterable: true) }
      let(:surname_field) { Column.new(procedure_id:, label: "Nom", table: "individual", column: "nom", displayable: true, type: :text, filterable: true) }
      let(:procedure) { create(:procedure, :for_individual) }

      it { is_expected.to include(name_field, surname_field) }
      it 'defines yes/no options for the for_tiers boolean column' do
        column = procedure.columns.find { _1.column == 'for_tiers' }

        expect(column.type).to eq(:boolean)
        expect(column.options_for_select).to eq(Champs::YesNoChamp.options)
      end

      it 'defines yes/no options for the submitted_with_france_connect boolean column' do
        column = procedure.columns.find { _1.column == 'submitted_with_france_connect' }

        expect(column).to be_present
        expect(column.type).to eq(:boolean)
        expect(column.options_for_select).to eq(Champs::YesNoChamp.options)
        expect(column.filterable).to be true
        expect(column.displayable).to be true
      end

      it 'defines yes/no options for the submitted_with_pro_connect boolean column' do
        column = procedure.columns.find { _1.column == 'submitted_with_pro_connect' }

        expect(column).to be_present
        expect(column.type).to eq(:boolean)
        expect(column.options_for_select).to eq(Champs::YesNoChamp.options)
        expect(column.filterable).to be true
        expect(column.displayable).to be true
      end
    end

    context 'when the procedure is sva' do
      let(:procedure) { create(:procedure, :sva) }

      let(:decision_on) { Column.new(procedure_id:, label: "Date décision SVA", table: "self", column: "sva_svr_decision_on", displayable: true, type: :date, filterable: true) }
      let(:decision_before_field) { Column.new(procedure_id:, label: "Date décision SVA avant", table: "self", column: "sva_svr_decision_before", displayable: false, type: :date, filterable: true) }

      it { is_expected.to include(decision_on, decision_before_field) }
    end

    context 'when the procedure is svr' do
      let(:procedure) { create(:procedure, :svr) }

      let(:decision_on) { Column.new(procedure_id:, label: "Date décision SVR", table: "self", column: "sva_svr_decision_on", displayable: true, type: :date, filterable: true) }
      let(:decision_before_field) { Column.new(procedure_id:, label: "Date décision SVR avant", table: "self", column: "sva_svr_decision_before", displayable: false, type: :date, filterable: true) }

      it { is_expected.to include(decision_on, decision_before_field) }
    end
  end

  describe 'export' do
    let(:procedure) { create(:procedure_with_dossiers, :published, public_type_de_champs:, for_individual:) }
    let(:for_individual) { true }
    let(:public_type_de_champs) do
      [
        { type: :text, libelle: "Ca va ?", mandatory: true, stable_id: 1 },
        { type: :communes, libelle: "Commune", mandatory: true, stable_id: 17 },
        { type: :siret, libelle: 'siret', stable_id: 20 },
        { type: :repetition, mandatory: true, stable_id: 7, libelle: "Champ répétable", children: [{ type: 'text', libelle: 'Qqchose à rajouter?', stable_id: 8 }] },
      ]
    end

    describe '#usager_columns_for_export' do
      context 'for individual procedure' do
        let(:for_individual) { true }

        it "returns all usager columns" do
          expected = [
            procedure.find_column(label: "N° dossier"),
            procedure.find_column(label: "Adresse électronique"),
            procedure.find_column(label: "France connecté ?"),
            procedure.find_column(label: "Nom [Identité du demandeur]"),
            procedure.find_column(label: "Prénom [Identité du demandeur]"),
            procedure.find_column(label: "Dépôt pour un tiers"),
            procedure.find_column(label: "Nom [Identité du mandataire]"),
            procedure.find_column(label: "Prénom [Identité du mandataire]"),
          ]
          actuals = procedure.usager_columns_for_export.map(&:h_id)
          expected.each do |expected_col|
            expect(actuals).to include(expected_col.h_id)
          end
        end
      end

      context 'for entreprise procedure' do
        let(:for_individual) { false }

        it "returns all usager columns" do
          expected = [
            procedure.find_column(label: "N° dossier"),
            procedure.find_column(label: "Adresse électronique"),
            procedure.find_column(label: "France connecté ?"),
            procedure.find_column(label: "Établissement SIRET"),
            procedure.find_column(label: "Établissement siège social"),
            procedure.find_column(label: "Libellé NAF"),
            procedure.find_column(label: "Code NAF"),
            procedure.find_column(label: "Établissement Adresse"),
            procedure.find_column(label: "Établissement numero voie"),
            procedure.find_column(label: "Établissement type voie"),
            procedure.find_column(label: "Établissement nom voie"),
            procedure.find_column(label: "Établissement complément adresse"),
            procedure.find_column(label: "Établissement code postal"),
            procedure.find_column(label: "Établissement localité"),
            procedure.find_column(label: "Établissement code INSEE localité"),
            procedure.find_column(label: "Entreprise SIREN"),
            procedure.find_column(label: "Entreprise capital social"),
            procedure.find_column(label: "Entreprise numero TVA intracommunautaire"),
            procedure.find_column(label: "Entreprise forme juridique"),
            procedure.find_column(label: "Entreprise forme juridique code"),
            procedure.find_column(label: "Entreprise nom commercial"),
            procedure.find_column(label: "Entreprise raison sociale"),
            procedure.find_column(label: "Entreprise SIRET siège social"),
            procedure.find_column(label: "Entreprise code effectif entreprise"),
          ]
          actuals = procedure.usager_columns_for_export
          expected.each do |expected_col|
            expect(actuals.map(&:h_id)).to include(expected_col.h_id)
          end

          expect(actuals.any? { _1.label == "Nom" }).to eq false
        end
      end

      context 'when procedure chorusable' do
        let(:procedure) { create(:procedure_with_dossiers, :filled_chorus, public_type_de_champs:) }
        it 'returns specific chorus columns' do
          allow_any_instance_of(Procedure).to receive(:chorusable?).and_return(true)
          expected = [
            procedure.find_column(label: "Domaine Fonctionnel"),
            procedure.find_column(label: "Référentiel De Programmation"),
            procedure.find_column(label: "Centre De Coût"),
          ]
          actuals = procedure.usager_columns_for_export.map(&:h_id)
          expected.each do |expected_col|
            expect(actuals).to include(expected_col.h_id)
          end
        end
      end
    end

    describe '#dossier_columns_for_export' do
      let(:procedure) { create(:procedure_with_dossiers, :routee, :published, public_type_de_champs:, for_individual:) }

      it "returns all dossier columns" do
        expected = [
          procedure.find_column(label: "Archivé"),
          procedure.find_column(label: "État du dossier"),
          procedure.find_column(label: "Date du dernier évènement"),
          procedure.find_column(label: "Date de dernière modification (usager)"),
          procedure.find_column(label: "Date de dépôt"),
          procedure.find_column(label: "Date de passage en instruction"),
          procedure.find_column(label: "Date de traitement"),
          procedure.find_column(label: "Motivation de la décision"),
          procedure.find_column(label: "Instructeurs"),
          procedure.find_column(label: "Groupe instructeur"),
          procedure.find_column(label: "Labels"),
        ]
        actuals = procedure.dossier_columns_for_export.map(&:h_id)
        expected.each do |expected_col|
          expect(actuals).to include(expected_col.h_id)
        end
      end
    end
  end

  describe '#customizable_columns' do
    include Logic

    let(:procedure) do
      create(:procedure, :published,
             public_type_de_champs: [
               { type: :text, libelle: 'Ville', mandatory: true },
               { type: :date, libelle: 'Date arrivée' },
               { type: :textarea, libelle: 'Description' },
               { type: :piece_justificative, libelle: 'Justificatif' },
               { type: :yes_no, libelle: 'Accord' },
               { type: :header_section, libelle: 'Section A' },
             ],
             private_type_de_champs: [
               { type: :text, libelle: 'Note interne' },
             ])
    end

    it 'includes proposable public champ types' do
      expect(procedure.customizable_columns.map(&:label)).to include('Ville', 'Date arrivée')
    end

    it 'excludes non-proposable types (textarea, piece_justificative, yes_no, header_section)' do
      labels = procedure.customizable_columns.map(&:label)
      expect(labels).not_to include('Description', 'Justificatif', 'Accord', 'Section A')
    end

    it 'excludes private annotations' do
      expect(procedure.customizable_columns.map(&:label)).not_to include('Note interne')
    end

    it 'returns Columns::ChampColumn instances carrying mandatory flag' do
      expect(procedure.customizable_columns).to all(be_a(Columns::ChampColumn))
      ville_column = procedure.customizable_columns.find { _1.label == 'Ville' }
      expect(ville_column.mandatory).to eq(true)
    end

    it 'returns a single entry for a multi-column champ like address' do
      procedure = create(:procedure, :published, public_type_de_champs: [{ type: :address, libelle: 'Domicile' }])
      columns = procedure.customizable_columns.filter { _1.label.include?('Domicile') }
      expect(columns.size).to eq(1)
      expect(columns.first.tdc_type).to eq('address')
    end

    it 'offers the commune name column for a commune champ' do
      procedure = create(:procedure, :published, public_type_de_champs: [{ type: :communes, libelle: 'Ville de naissance' }])
      dossier = create(:dossier, :with_populated_champs, procedure:)

      column = procedure.customizable_columns.sole
      expect(column.label).to eq('Ville de naissance – Commune')
      expect(column.value(dossier.champs.first)).to eq('Coye-la-Forêt')
    end

    it 'offers the canonical column for a single-column champ' do
      ville_column = procedure.customizable_columns.find { _1.label == 'Ville' }
      expect(ville_column.h_id[:column_id]).to eq("type_de_champ/#{ville_column.stable_id}")
    end

    it 'excludes champs that carry a condition' do
      procedure = create(:procedure, :published, public_type_de_champs: [
        { type: :yes_no, libelle: 'Gate', stable_id: 1 },
        { type: :text, libelle: 'Toujours visible' },
        { type: :text, libelle: 'Conditionné', condition: ds_eq(champ_value(1), constant(true)) },
      ])

      expect(procedure.customizable_columns.map(&:label)).to eq(['Toujours visible'])
    end

    it 'excludes a champ conditioned in the published revision even if unconditioned in an older revision' do
      procedure = create(:procedure, :published, public_type_de_champs: [
        { type: :yes_no, libelle: 'Gate', stable_id: 1 },
        { type: :text, libelle: 'Cible', stable_id: 2 },
      ])
      tdc = procedure.draft_revision.find_and_ensure_exclusive_use(2)
      tdc.update!(condition: ds_eq(champ_value(1), constant(true)))
      procedure.publish_revision!(procedure.administrateurs.first)
      procedure.reload

      expect(procedure.customizable_columns.map(&:label)).not_to include('Cible')
    end

    it 'excludes a champ removed from the published revision even if present in an older revision' do
      procedure = create(:procedure, :published, public_type_de_champs: [
        { type: :text, libelle: 'Conservé', stable_id: 1 },
        { type: :text, libelle: 'Supprimé', stable_id: 2 },
      ])
      procedure.draft_revision.remove_type_de_champ(2)
      procedure.publish_revision!(procedure.administrateurs.first)
      procedure.reload

      expect(procedure.customizable_columns.map(&:label)).to eq(['Conservé'])
    end
  end

  describe '#customizable_columns_by_section' do
    include Logic

    let(:procedure) do
      create(:procedure, :published,
             public_type_de_champs: [
               { type: :text, libelle: 'Avant section' },
               { type: :header_section, libelle: 'Identité' },
               { type: :text, libelle: 'Nom' },
               { type: :textarea, libelle: 'Bio' },
               { type: :header_section, libelle: 'Adresse' },
               { type: :address, libelle: 'Domicile' },
             ])
    end

    it 'groups personnalisable columns under their preceding section, in form order' do
      result = procedure.customizable_columns_by_section
      labels = result.map { |_stable_id, section_label, columns| [section_label, columns.map(&:label)] }

      expect(labels).to eq([
        [nil, ['Avant section']],
        ['1. Identité', ['Nom']],
        ['2. Adresse', ['Domicile']],
      ])
    end

    it 'omits sections that contain no personnalisable column but counts them for numbering' do
      procedure = create(:procedure, :published, public_type_de_champs: [
        { type: :header_section, libelle: 'Vide' },
        { type: :textarea, libelle: 'Long' },
        { type: :header_section, libelle: 'Pleine' },
        { type: :text, libelle: 'Court' },
      ])

      sections = procedure.customizable_columns_by_section.map { |_stable_id, label, _columns| label }
      expect(sections).to eq(['2. Pleine'])
    end

    it 'numbers sub-sections with dotted notation' do
      procedure = create(:procedure, :published, public_type_de_champs: [
        { type: :header_section, libelle: 'Parent', level: 1 },
        { type: :text, libelle: 'Champ parent' },
        { type: :header_section, libelle: 'Enfant', level: 2 },
        { type: :text, libelle: 'Champ enfant' },
      ])

      sections = procedure.customizable_columns_by_section.map { |_stable_id, label, _columns| label }
      expect(sections).to eq(['1. Parent', '1.1. Enfant'])
    end

    it 'does not auto-number when the admin already numbered at least one section' do
      procedure = create(:procedure, :published, public_type_de_champs: [
        { type: :header_section, libelle: '1. Identité' },
        { type: :text, libelle: 'Nom' },
        { type: :header_section, libelle: 'Représentant légal' },
        { type: :text, libelle: 'Fonction' },
      ])

      sections = procedure.customizable_columns_by_section.map { |_stable_id, label, _columns| label }
      expect(sections).to eq(['1. Identité', 'Représentant légal'])
    end

    it 'returns the section header stable_id as a stable key' do
      stable_ids = procedure.customizable_columns_by_section.map(&:first)
      header_stable_ids = procedure.published_revision.public_root_type_de_champs.filter(&:header_section?).map(&:stable_id)

      expect(stable_ids).to eq([nil, *header_stable_ids])
    end

    it 'does not query procedure_revisions or type_de_champs on each call (no N+1)' do
      p = Procedure.includes(published_revision: { revision_type_de_champs: :type_de_champ }).find(procedure.id)

      revision_query_count = 0
      tdc_query_count = 0
      ActiveSupport::Notifications.subscribed(
        lambda { |_n, _s, _f, _i, payload|
          sql = payload[:sql].to_s
          revision_query_count += 1 if sql.include?("procedure_revisions")
          tdc_query_count += 1 if sql.include?("type_de_champs")
        },
        "sql.active_record"
      ) { p.customizable_columns_by_section }

      expect(revision_query_count).to eq(0)
      expect(tdc_query_count).to eq(0)
    end

    it 'excludes champs that carry a condition' do
      procedure = create(:procedure, :published, public_type_de_champs: [
        { type: :yes_no, libelle: 'Gate', stable_id: 1 },
        { type: :text, libelle: 'Toujours visible' },
        { type: :text, libelle: 'Conditionné', condition: ds_eq(champ_value(1), constant(true)) },
      ])

      labels = procedure.customizable_columns_by_section.flat_map { |_stable_id, _label, columns| columns.map(&:label) }
      expect(labels).to eq(['Toujours visible'])
    end
  end

  describe 'colonnes SVA d’une démarche désactivée' do
    before_all { seed "cases/sva" }

    let(:procedure) { procedures.sva }

    before { procedure.update_column(:sva_svr, procedure.sva_svr.merge('disabled_at' => Time.current.iso8601)) }

    it 'garde la colonne de date et son filtre' do
      column_ids = procedure.columns.map(&:column)

      expect(column_ids).to include('sva_svr_decision_on')
      expect(column_ids).to include('sva_svr_decision_before')
    end

    it 'garde la colonne dans les colonnes exportables' do
      expect(procedure.dossier_columns_for_export.map(&:column)).to include('sva_svr_decision_on')
    end

    it 'reste résoluble par find_column, donc par une présentation enregistrée' do
      column = procedure.columns.find { it.column == 'sva_svr_decision_on' }

      expect { procedure.find_column(h_id: column.h_id) }.not_to raise_error
    end
  end
end
