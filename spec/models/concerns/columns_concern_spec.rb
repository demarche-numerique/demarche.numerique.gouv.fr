# frozen_string_literal: true

describe ColumnsConcern do
  let(:procedure_id) { procedure.id }

  describe '#find_column' do
    let(:types_de_champ_public) do
      [
        { type: :linked_drop_down_list, libelle: 'linked' },
        { type: :address, libelle: 'address' },
      ]
    end
    let(:procedure) { create(:procedure, types_de_champ_public:) }
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
      let(:linked_tdc) { procedure.active_revision.types_de_champ.find { _1.type_champ == 'linked_drop_down_list' } }

      it do
        column_id = "type_de_champ/#{linked_tdc.stable_id}->value"

        h_id = { procedure_id:, column_id: }
        expect(procedure.find_column(h_id:)).to eq(linked_drop_down_column)
      end
    end

    context 'when the colum_id is an old department column id' do
      let(:department_column) { procedure.find_column(label: "address – Département") }
      let(:address_tdc) { procedure.active_revision.types_de_champ.find { _1.type_champ == 'address' } }

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
  end

  describe "#columns" do
    subject { procedure.columns }

    context 'when the procedure can have a SIRET number' do
      let(:procedure) { create(:procedure, types_de_champ_public:, types_de_champ_private:) }
      let(:tdc_1) { procedure.active_revision.types_de_champ_public[0] }
      let(:tdc_2) { procedure.active_revision.types_de_champ_public[1] }
      let(:tdc_private_1) { procedure.active_revision.types_de_champ_private[0] }
      let(:tdc_private_2) { procedure.active_revision.types_de_champ_private[1] }
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
          { label: 'Code postal', table: 'etablissement', column: 'code_postal', displayable: true, type: :text, filterable: true },
          { label: tdc_1.libelle, table: 'type_de_champ', column: tdc_1.stable_id.to_s, displayable: true, type: :text, filterable: true },
          { label: tdc_2.libelle, table: 'type_de_champ', column: tdc_2.stable_id.to_s, displayable: true, type: :text, filterable: true },
          { label: tdc_private_1.libelle, table: 'type_de_champ', column: tdc_private_1.stable_id.to_s, displayable: true, type: :text, filterable: true },
          { label: tdc_private_2.libelle, table: 'type_de_champ', column: tdc_private_2.stable_id.to_s, displayable: true, type: :text, filterable: true },
        ].map { Column.new(**_1.merge(procedure_id:)) }
      }

      context 'with explication/header_sections' do
        let(:types_de_champ_public) { Array.new(4) { { type: :text } } }
        let(:types_de_champ_private) { Array.new(4) { { type: :text } } }
        before do
          procedure.active_revision.types_de_champ_public[2].update_attribute(:type_champ, TypeDeChamp.type_champs.fetch(:header_section))
          procedure.active_revision.types_de_champ_public[3].update_attribute(:type_champ, TypeDeChamp.type_champs.fetch(:explication))
          procedure.active_revision.types_de_champ_private[2].update_attribute(:type_champ, TypeDeChamp.type_champs.fetch(:header_section))
          procedure.active_revision.types_de_champ_private[3].update_attribute(:type_champ, TypeDeChamp.type_champs.fetch(:explication))
        end

        it {
          expected.each do |expected|
            expect(subject).to include(expected)
          end
        }
      end

      context 'with rna' do
        let(:types_de_champ_public) { [{ type: :rna, libelle: 'RNA' }] }
        let(:types_de_champ_private) { [] }
        it { expect(subject.map(&:label)).to include('RNA – Commune') }
      end

      context 'with linked drop down list' do
        let(:types_de_champ_public) { [{ type: :linked_drop_down_list, libelle: 'linked' }] }
        let(:types_de_champ_private) { [] }
        it {
          expect(subject.map(&:label)).to include('linked (Primaire)')
          expect(subject.map(&:label)).to include('linked (Secondaire)')
        }
      end

      context 'with drop down list with csv referentiel' do
        let(:types_de_champ_public) { [{ type: :drop_down_list, libelle: 'liste csv', drop_down_mode: 'advanced', referentiel: }] }
        let(:referentiel) { create(:csv_referentiel, :with_items) }
        let(:types_de_champ_private) { [] }
        it {
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
    let(:procedure) { create(:procedure_with_dossiers, :published, types_de_champ_public:, for_individual:) }
    let(:for_individual) { true }
    let(:types_de_champ_public) do
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
        let(:procedure) { create(:procedure_with_dossiers, :filled_chorus, types_de_champ_public:) }
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
      let(:procedure) { create(:procedure_with_dossiers, :routee, :published, types_de_champ_public:, for_individual:) }

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
end
