# frozen_string_literal: true

describe DossierFilterService do
  def to_filter((label, filter)) = FilteredColumn.new(column: procedure.find_column(label:), filter:)

  describe '.filtered_sorted_ids' do
    let(:procedure) { create(:procedure) }
    let(:instructeur) { create(:instructeur) }
    let(:dossiers) { procedure.dossiers }
    let(:statut) { 'suivis' }
    let(:filters) { [] }
    let(:include_archived) { false }
    let(:sorted_columns) { procedure.default_sorted_column }

    subject { described_class.filtered_sorted_ids(dossiers, statut, filters, sorted_columns, instructeur, include_archived:) }

    context 'with no filters' do
      let(:en_construction_dossier) { create(:dossier, :en_construction, procedure:) }
      let(:accepte_dossier) { create(:dossier, :accepte, procedure:) }
      let(:archived_dossier) { create(:dossier, :accepte, :archived, procedure:) }

      before do
        create(:follow, dossier: en_construction_dossier, instructeur:)
        create(:follow, dossier: accepte_dossier, instructeur:)
        create(:follow, dossier: archived_dossier, instructeur:)
      end

      it { is_expected.to contain_exactly(en_construction_dossier.id) }

      context 'when include_archived is true' do
        let(:include_archived) { true }
        let(:statut) { 'tous' }

        it { is_expected.to contain_exactly(en_construction_dossier.id, accepte_dossier.id, archived_dossier.id) }
      end
    end

    context 'with mocked sorted_ids' do
      let(:dossier_1) { create(:dossier) }
      let(:dossier_2) { create(:dossier) }
      let(:dossier_3) { create(:dossier) }
      let(:dossiers) { Dossier.where(id: [dossier_1, dossier_2, dossier_3].map(&:id)) }

      let(:sorted_ids) { [dossier_2, dossier_3, dossier_1].map(&:id) }

      before do
        expect(described_class).to receive(:sorted_ids).and_return(sorted_ids)
      end

      it { is_expected.to eq(sorted_ids) }

      context 'when a filter is present' do
        let(:filtered_ids) { [dossier_1, dossier_2, dossier_3].map(&:id) }
        let(:filters) { [to_filter(['État du dossier', 'en_construction'])] }

        before do
          expect(described_class).to receive(:filtered_ids).and_return(filtered_ids)
        end

        it { is_expected.to eq(sorted_ids) }
      end
    end
  end

  describe '#sorted_ids' do
    let(:procedure) { create(:procedure, :published, types_de_champ_public:, types_de_champ_private: [{}]) }
    let(:types_de_champ_public) { [{}] }
    let(:first_type_de_champ) { assign_to.procedure.active_revision.types_de_champ_public.first }
    let(:dossiers) { procedure.dossiers }
    let(:instructeur) { create(:instructeur) }
    let(:assign_to) { create(:assign_to, procedure:, instructeur:) }
    let(:sorted_column) { SortedColumn.new(column:, order:) }

    subject { described_class.send(:sorted_ids, dossiers, sorted_column, instructeur, dossiers.count) }

    context 'for notifications table' do
      let(:column) { procedure.notifications_column }
      let!(:recent_dossier) { create(:dossier, :en_construction, procedure:) }
      let!(:older_dossier) { create(:dossier, :en_construction, procedure:) }

      before do
        recent_dossier.touch(time: Time.zone.local(2018, 9, 25))
        older_dossier.touch(time: Time.zone.local(2018, 5, 13))
      end

      context 'in ascending order' do
        let(:order) { 'asc' }

        it { is_expected.to eq([older_dossier, recent_dossier].map(&:id)) }
      end

      context 'in descending order' do
        let(:order) { 'desc' }

        let!(:dossier_notif) { create(:dossier, :en_construction, procedure:) }
        let!(:notif_instructeur_1) { create(:dossier_notification, instructeur:, dossier: dossier_notif, notification_type: :attente_avis) }
        let(:other_instructeur) { create(:instructeur) }
        let!(:notif_other_instructeur) { create(:dossier_notification, instructeur: other_instructeur, dossier: recent_dossier) }
        let!(:dossier_2_notif) { create(:dossier, :en_construction, procedure:) }
        let!(:notif_instructeur_2) { create(:dossier_notification, instructeur:, dossier: dossier_2_notif) }
        let!(:notif_not_display) { create(:dossier_notification, instructeur:, dossier: older_dossier, display_at: 1.day.from_now) }

        it { is_expected.to eq([dossier_2_notif, dossier_notif, recent_dossier, older_dossier].map(&:id)) }
      end
    end

    context 'for self table' do
      let(:order) { 'asc' } # Desc works the same, no extra test required

      context 'for created_at column' do
        let!(:column) { procedure.find_column(label: 'Date de création') }
        let!(:recent_dossier) { travel_to(Time.zone.local(2018, 10, 17)) { create(:dossier, procedure:) } }
        let!(:older_dossier) { travel_to(Time.zone.local(2003, 11, 11)) { create(:dossier, procedure:) } }

        it { is_expected.to eq([older_dossier, recent_dossier].map(&:id)) }
      end

      context 'for en_construction_at column' do
        let!(:column) { procedure.find_column(label: 'Date de passage en construction') }
        let!(:recent_dossier) { create(:dossier, :en_construction, procedure:, en_construction_at: Time.zone.local(2018, 10, 17)) }
        let!(:older_dossier) { create(:dossier, :en_construction, procedure:, en_construction_at: Time.zone.local(2013, 1, 1)) }

        it { is_expected.to eq([older_dossier, recent_dossier].map(&:id)) }
      end

      context 'for updated_at column' do
        let(:column) { procedure.find_column(label: 'Date du dernier évènement') }
        let(:recent_dossier) { create(:dossier, procedure:) }
        let(:older_dossier) { create(:dossier, procedure:) }

        before do
          recent_dossier.touch(time: Time.zone.local(2018, 9, 25))
          older_dossier.touch(time: Time.zone.local(2018, 5, 13))
        end

        it { is_expected.to eq([older_dossier, recent_dossier].map(&:id)) }
      end
    end

    context 'for type_de_champ table' do
      context 'with no revisions' do
        let(:column) { procedure.find_column(label: first_type_de_champ.libelle) }

        let(:beurre_dossier) { create(:dossier, procedure:) }
        let(:tartine_dossier) { create(:dossier, procedure:) }

        before do
          beurre_dossier.project_champs_public.first.update(value: 'beurre')
          tartine_dossier.project_champs_public.first.update(value: 'tartine')
        end

        context 'asc' do
          let(:order) { 'asc' }

          it { is_expected.to eq([beurre_dossier, tartine_dossier].map(&:id)) }
        end

        context 'desc' do
          let(:order) { 'desc' }

          it { is_expected.to eq([tartine_dossier, beurre_dossier].map(&:id)) }
        end
      end

      context 'with a revision adding a new type_de_champ' do
        let!(:tdc) { { type_champ: :text, libelle: 'nouveau champ' } }
        let(:column) { procedure.find_column(label: 'nouveau champ') }

        let!(:nothing_dossier) { create(:dossier, procedure:) }
        let!(:beurre_dossier) { create(:dossier, procedure:) }
        let!(:tartine_dossier) { create(:dossier, procedure:) }

        before do
          nothing_dossier
          procedure.draft_revision.add_type_de_champ(tdc)
          procedure.publish_revision!(procedure.administrateurs.first)
          beurre_dossier.project_champs_public.last.update(value: 'beurre')
          tartine_dossier.project_champs_public.last.update(value: 'tartine')
        end

        context 'asc' do
          let(:order) { 'asc' }
          it { is_expected.to eq([nothing_dossier, beurre_dossier, tartine_dossier].map(&:id)) }
        end

        context 'desc' do
          let(:order) { 'desc' }
          it { is_expected.to eq([tartine_dossier, beurre_dossier, nothing_dossier].map(&:id)) }
        end
      end
    end

    context 'for type_de_champ_private table' do
      context 'with no revisions' do
        let(:column) { procedure.find_column(label: procedure.active_revision.types_de_champ_private.first.libelle) }

        let(:biere_dossier) { create(:dossier, procedure:) }
        let(:vin_dossier) { create(:dossier, procedure:) }

        before do
          biere_dossier.project_champs_private.first.update(value: 'biere')
          vin_dossier.project_champs_private.first.update(value: 'vin')
        end

        context 'asc' do
          let(:order) { 'asc' }

          it { is_expected.to eq([biere_dossier, vin_dossier].map(&:id)) }
        end

        context 'desc' do
          let(:order) { 'desc' }

          it { is_expected.to eq([vin_dossier, biere_dossier].map(&:id)) }
        end
      end
    end

    context 'for individual table' do
      let(:order) { 'asc' } # Desc works the same, no extra test required

      let(:procedure) { create(:procedure, :for_individual) }

      let!(:first_dossier) { create(:dossier, procedure:, individual: build(:individual, gender: 'M', prenom: 'Alain', nom: 'Antonelli')) }
      let!(:last_dossier) { create(:dossier, procedure:, individual: build(:individual, gender: 'Mme', prenom: 'Zora', nom: 'Zemmour')) }

      context 'for gender column' do
        before do
          procedure.update!(no_gender: false)
        end

        let(:column) { procedure.find_column(label: 'Civilité') }

        it { is_expected.to eq([first_dossier, last_dossier].map(&:id)) }
      end

      context 'for prenom column' do
        let(:column) { procedure.find_column(label: 'Prénom') }

        it { is_expected.to eq([first_dossier, last_dossier].map(&:id)) }
      end

      context 'for nom column' do
        let(:column) { procedure.find_column(label: 'Nom') }

        it { is_expected.to eq([first_dossier, last_dossier].map(&:id)) }
      end
    end

    context 'for followers_instructeurs table' do
      let(:order) { 'asc' } # Desc works the same, no extra test required

      let!(:dossier_z) { create(:dossier, :en_construction, procedure:) }
      let!(:dossier_a) { create(:dossier, :en_construction, procedure:) }
      let!(:dossier_without_instructeur) { create(:dossier, :en_construction, procedure:) }

      before do
        create(:follow, dossier: dossier_z, instructeur: create(:instructeur, email: 'zythum@exemple.fr'))
        create(:follow, dossier: dossier_a, instructeur: create(:instructeur, email: 'abaca@exemple.fr'))
        create(:follow, dossier: dossier_a, instructeur: create(:instructeur, email: 'abaca2@exemple.fr'))
      end

      context 'for email column' do
        let(:column) { procedure.find_column(label: 'Instructeurs') }

        it { is_expected.to eq([dossier_a, dossier_z, dossier_without_instructeur].map(&:id)) }
      end
    end

    context 'for avis table' do
      let(:column) { procedure.find_column(label: 'Avis oui/non') }
      let(:order) { 'asc' }

      let!(:dossier_yes) { create(:dossier, procedure:) }
      let!(:dossier_no) { create(:dossier, procedure:) }

      before do
        create_list(:avis, 2, dossier: dossier_yes, question_answer: true)
        create(:avis,  dossier: dossier_no, question_answer: true)
        create(:avis,  dossier: dossier_no, question_answer: false)
      end

      it { is_expected.to eq([dossier_no, dossier_yes].map(&:id)) }
    end

    context 'for labels table' do
      let(:column) { procedure.find_column(label: 'Labels') }

      let(:label_a) { Label.create(name: "a", color: 'green-bourgeon', procedure:) }
      let(:label_z) { Label.create(name: "z", color: 'green-bourgeon', procedure:) }
      let!(:dossier_z) { create(:dossier, procedure:) }
      let!(:dossier_a) { create(:dossier, procedure:) }
      let!(:dossier_no_label) { create(:dossier, procedure:) }
      let!(:dossier_label_a) { DossierLabel.create(dossier: dossier_a, label: label_a) }
      let!(:dossier_label_z) { DossierLabel.create(dossier: dossier_z, label: label_z) }

      context 'asc' do
        let(:order) { 'asc' }
        it { is_expected.to eq([dossier_a, dossier_z, dossier_no_label].map(&:id)) }
      end

      context 'desc' do
        let(:order) { 'desc' }
        it { is_expected.to eq([dossier_no_label, dossier_z, dossier_a].map(&:id)) }
      end
    end

    context 'for other tables' do
      # All other columns and tables work the same so it’s ok to test only one
      let(:column) { procedure.find_column(label: 'Établissement code postal') }
      let(:order) { 'asc' } # Desc works the same, no extra test required

      let!(:huitieme_dossier) { create(:dossier, procedure:, etablissement: create(:etablissement, code_postal: '75008')) }
      let!(:vingtieme_dossier) { create(:dossier, procedure:, etablissement: create(:etablissement, code_postal: '75020')) }

      it { is_expected.to eq([huitieme_dossier, vingtieme_dossier].map(&:id)) }
    end

    context 'for etablissement code_naf column (aliased to naf)' do
      let(:column) { procedure.find_column(label: 'Code NAF') }
      let(:order) { 'asc' }

      let!(:first_dossier) { create(:dossier, procedure:, etablissement: create(:etablissement, naf: '1234Z')) }
      let!(:second_dossier) { create(:dossier, procedure:, etablissement: create(:etablissement, naf: '9999Z')) }

      it { is_expected.to eq([first_dossier.id, second_dossier.id]) }
    end
  end

  describe '#filtered_ids' do
    let(:procedure) { create(:procedure, types_de_champ_public:, types_de_champ_private:) }
    let(:types_de_champ_public) { [{}] }
    let(:types_de_champ_private) { [{}] }
    let(:dossiers) { procedure.dossiers }
    let(:filtered_columns) { filters.map { to_filter(_1) } }
    let(:filters) { [filter] }

    subject { described_class.send(:filtered_ids, dossiers.joins(:user), filtered_columns) }

    context 'for self table' do
      context 'for created_at column' do
        let(:filter) { ['Date de création', '18/9/2018'] }

        let!(:dossier_18_sept) { create(:dossier, procedure:, created_at: Time.zone.local(2018, 9, 18, 14, 28)) }
        let!(:dossier_16_sept) { create(:dossier, procedure:, created_at: Time.zone.local(2018, 9, 16, 23, 59)) }

        it { is_expected.to contain_exactly(dossier_18_sept.id) }

        context 'with operator match' do
          let(:filter) { ['Date de création', { operator: 'match', value: ['18/09/2018'] }] }

          it { is_expected.to contain_exactly(dossier_18_sept.id) }
        end

        context 'with operator before' do
          let(:filter) { ['Date de création', { operator: 'before', value: ['17/09/2018'] }] }

          it { is_expected.to contain_exactly(dossier_16_sept.id) }
        end

        context 'with operator after' do
          let(:filter) { ['Date de création', { operator: 'after', value: ['17/09/2018'] }] }

          it { is_expected.to contain_exactly(dossier_18_sept.id) }
        end
      end

      context 'for en_construction_at column' do
        let(:filter) { ['Date de passage en construction', '17/10/2018'] }

        let!(:kept_dossier) { create(:dossier, :en_construction, procedure:, en_construction_at: Time.zone.local(2018, 10, 17)) }
        let!(:discarded_dossier) { create(:dossier, :en_construction, procedure:, en_construction_at: Time.zone.local(2013, 1, 1)) }

        it { is_expected.to contain_exactly(kept_dossier.id) }
      end

      context 'for updated_at column' do
        let(:filter) { ['Date du dernier évènement', '18/9/2018'] }

        let(:kept_dossier) { create(:dossier, procedure:) }
        let(:discarded_dossier) { create(:dossier, procedure:) }

        before do
          kept_dossier.touch(time: Time.zone.local(2018, 9, 18, 14, 28))
          discarded_dossier.touch(time: Time.zone.local(2018, 9, 17, 23, 59))
        end

        it { is_expected.to contain_exactly(kept_dossier.id) }
      end

      context 'for updated_since column' do
        let(:filter) { ['Dernier évènement depuis', '18/9/2018'] }

        let(:kept_dossier) { create(:dossier, procedure:) }
        let(:later_dossier) { create(:dossier, procedure:) }
        let(:discarded_dossier) { create(:dossier, procedure:) }

        before do
          kept_dossier.touch(time: Time.zone.local(2018, 9, 18, 14, 28))
          later_dossier.touch(time: Time.zone.local(2018, 9, 19, 14, 28))
          discarded_dossier.touch(time: Time.zone.local(2018, 9, 17, 14, 28))
        end

        it { is_expected.to match_array([kept_dossier.id, later_dossier.id]) }
      end

      context 'for sva_svr_decision_before column' do
        before do
          travel_to Time.zone.local(2023, 6, 10, 10)
        end

        let(:procedure) { create(:procedure, :published, :sva, types_de_champ_public: [{}], types_de_champ_private: [{}]) }
        let(:filter) { ['Date décision SVA avant', '15/06/2023'] }

        let!(:kept_dossier) { create(:dossier, :en_instruction, procedure:, sva_svr_decision_on: Date.current) }
        let!(:later_dossier) { create(:dossier, :en_instruction, procedure:, sva_svr_decision_on: Date.current + 2.days) }
        let!(:discarded_dossier) { create(:dossier, :en_instruction, procedure:, sva_svr_decision_on: Date.current + 10.days) }
        let!(:en_construction_dossier) { create(:dossier, :en_construction, procedure:, sva_svr_decision_on: Date.current + 2.days) }
        let!(:accepte_dossier) { create(:dossier, :accepte, procedure:, sva_svr_decision_on: Date.current + 2.days) }

        it { is_expected.to match_array([kept_dossier.id, later_dossier.id, en_construction_dossier.id]) }
      end

      context 'ignore time of day' do
        let(:filter) { ['Date de passage en construction', '17/10/2018 19:30'] }

        let!(:kept_dossier) { create(:dossier, :en_construction, procedure:, en_construction_at: Time.zone.local(2018, 10, 17, 15, 56)) }
        let!(:discarded_dossier) { create(:dossier, :en_construction, procedure:, en_construction_at: Time.zone.local(2018, 10, 18, 5, 42)) }

        it { is_expected.to contain_exactly(kept_dossier.id) }
      end

      context 'for a malformed date' do
        context 'when its a string' do
          let(:filter) { ['Date du dernier évènement', 'malformed date'] }

          it { is_expected.to match([]) }
        end

        context 'when its a number' do
          let(:filter) { ['Date du dernier évènement', '177500'] }

          it { is_expected.to match([]) }
        end
      end

      context 'with multiple search values' do
        let(:filters) { [['Date de passage en construction', '17/10/2018'], ['Date de passage en construction', '19/10/2018']] }

        let!(:kept_dossier) { create(:dossier, :en_construction, procedure:, en_construction_at: Time.zone.local(2018, 10, 17)) }
        let!(:other_kept_dossier) { create(:dossier, :en_construction, procedure:, en_construction_at: Time.zone.local(2018, 10, 19)) }
        let!(:discarded_dossier) { create(:dossier, :en_construction, procedure:, en_construction_at: Time.zone.local(2013, 1, 1)) }

        it 'returns every dossier that matches any of the search criteria for a given column' do
          is_expected.to contain_exactly(kept_dossier.id, other_kept_dossier.id)
        end
      end

      context 'with multiple state filters' do
        let(:filters) { [['État du dossier', 'en_construction'], ['État du dossier', 'en_instruction']] }

        let!(:kept_dossier) { create(:dossier, :en_construction, procedure:) }
        let!(:other_kept_dossier) { create(:dossier, :en_instruction, procedure:) }
        let!(:discarded_dossier) { create(:dossier, :accepte, procedure:) }

        it 'returns every dossier that matches any of the search criteria for a given column' do
          is_expected.to contain_exactly(kept_dossier.id, other_kept_dossier.id)
        end
      end

      context 'with en_construction state filters' do
        let(:filter) { ['État du dossier', 'en_construction'] }

        let!(:en_construction) { create(:dossier, :en_construction, procedure:) }
        let!(:en_construction_with_correction) { create(:dossier, :en_construction, procedure:) }
        let!(:correction) { create(:dossier_correction, dossier: en_construction_with_correction) }
        it 'returns only dossier en construction with and without pending correction' do
          is_expected.to contain_exactly(en_construction.id, en_construction_with_correction.id)
        end
      end
    end

    context 'for type_de_champ table' do
      let(:filter) { [type_de_champ.libelle, ' Kéep '] } # add space / case / accent

      let(:kept_dossier) { create(:dossier, procedure:) }
      let(:discarded_dossier) { create(:dossier, procedure:) }
      let(:type_de_champ) { procedure.active_revision.types_de_champ_public.first }

      context 'with single value' do
        before do
          kept_dossier.champs.find_by(stable_id: type_de_champ.stable_id).update(value: 'keep me')
          discarded_dossier.champs.find_by(stable_id: type_de_champ.stable_id).update(value: 'discard me')
        end

        it { is_expected.to contain_exactly(kept_dossier.id) }
      end

      context 'with multiple search values' do
        let(:filters) { [[type_de_champ.libelle, 'keep'], [type_de_champ.libelle, 'and']] }
        let(:other_kept_dossier) { create(:dossier, procedure:) }

        before do
          kept_dossier.champs.find_by(stable_id: type_de_champ.stable_id).update(value: 'keep me')
          discarded_dossier.champs.find_by(stable_id: type_de_champ.stable_id).update(value: 'discard me')
          other_kept_dossier.champs.find_by(stable_id: type_de_champ.stable_id).update(value: 'and me too')
        end

        it 'returns every dossier that matches any of the search criteria for a given column' do
          is_expected.to contain_exactly(kept_dossier.id, other_kept_dossier.id)
        end
      end

      context 'with yes_no type_de_champ' do
        let(:filter) { [type_de_champ.libelle, 'true'] }
        let(:types_de_champ_public) { [{ type: :yes_no }] }

        before do
          kept_dossier.champs.find_by(stable_id: type_de_champ.stable_id).update(value: 'true')
          discarded_dossier.champs.find_by(stable_id: type_de_champ.stable_id).update(value: 'false')
        end

        it { is_expected.to contain_exactly(kept_dossier.id) }
      end

      context 'with departement type_de_champ' do
        let(:filter) { [type_de_champ.libelle, '13'] }
        let(:types_de_champ_public) { [{ type: :departements }] }

        before do
          kept_dossier.champs.find_by(stable_id: type_de_champ.stable_id).update(external_id: '13')
          discarded_dossier.champs.find_by(stable_id: type_de_champ.stable_id).update(external_id: '69')
        end

        it { is_expected.to contain_exactly(kept_dossier.id) }
      end

      context 'with enum type_de_champ' do
        let(:filter) { [type_de_champ.libelle, 'Favorable'] }
        let(:types_de_champ_public) { [{ type: :drop_down_list, options: ['Favorable', 'Defavorable'] }] }

        before do
          kept_dossier.champs.find_by(stable_id: type_de_champ.stable_id).update(value: 'Favorable')
          discarded_dossier.champs.find_by(stable_id: type_de_champ.stable_id).update(external_id: 'Defavorable')
        end

        it { is_expected.to contain_exactly(kept_dossier.id) }
      end

      context 'with multiple filters' do
        let(:filters) { [filter_resto, filter_a_emporter] }
        let(:filter_resto) { [type_de_champ_resto.libelle, 'pizzeria'] }
        let(:filter_a_emporter) { [type_de_champ_a_emporter.libelle, 'true'] }

        let(:types_de_champ_public) do
          [
            { type: :drop_down_list, options: ['pizzeria', 'gastronomique'] },
            { type: :yes_no },
          ]
        end
        let(:types_de_champ) { procedure.active_revision.types_de_champ_public }
        let(:type_de_champ_resto) { types_de_champ[0] }
        let(:type_de_champ_a_emporter) { types_de_champ[1] }

        let(:another_discarded_dossier) { create(:dossier, procedure:) }

        before do
          kept_champ_resto = kept_dossier.champs.find_by(stable_id: type_de_champ_resto.stable_id)
          kept_champ_resto.value = 'pizzeria'
          kept_champ_resto.save!

          kept_champ_a_emporter = kept_dossier.champs.find_by(stable_id: type_de_champ_a_emporter.stable_id)
          kept_champ_a_emporter.value = 'true'
          kept_champ_a_emporter.save!

          discarded_champ_resto = discarded_dossier.champs.find_by(stable_id: type_de_champ_resto.stable_id)
          discarded_champ_resto.value = 'pizzeria'
          discarded_champ_a_emporter = discarded_dossier.champs.find_by(stable_id: type_de_champ_a_emporter.stable_id)
          discarded_champ_a_emporter.value = 'false'
          discarded_champ_resto.save!
          discarded_champ_a_emporter.save!

          another_discarded_champ_resto = another_discarded_dossier.champs.find_by(stable_id: type_de_champ_resto.stable_id)
          another_discarded_champ_resto.value = 'fast-food'
          another_discarded_champ_a_emporter = another_discarded_dossier.champs.find_by(stable_id: type_de_champ_a_emporter.stable_id)
          another_discarded_champ_a_emporter.value = 'true'
          another_discarded_champ_resto.save!
          another_discarded_champ_a_emporter.save!
        end

        it { is_expected.to contain_exactly(kept_dossier.id) }
      end

      context 'with enums type_de_champ' do
        let(:filter) { [type_de_champ.libelle, search_term] }
        let(:types_de_champ_public) { [{ type: :multiple_drop_down_list, options: ['champ', 'champignon'] }] }

        before do
          kept_champ = kept_dossier.champs.find_by(stable_id: type_de_champ.stable_id)
          kept_champ.value = ['champ', 'champignon']
          kept_champ.save!

          discarded_champ = discarded_dossier.champs.find_by(stable_id: type_de_champ.stable_id)
          discarded_champ.value = ['champignon']
          discarded_champ.save!
        end

        context 'with single value' do
          let(:search_term) { 'champ' }

          it { is_expected.to contain_exactly(kept_dossier.id) }
        end

        context 'with multiple search values' do
          let(:search_term) { 'champignon' }

          it { is_expected.to contain_exactly(kept_dossier.id, discarded_dossier.id) }
        end

        context 'test if I could break a regex with %' do
          let(:search_term) { '%' }

          it { is_expected.to be_empty }
        end

        context 'test if I could break a regex with .' do
          let(:search_term) { '.*' }

          it { is_expected.to be_empty }
        end
      end

      context "with filter with match operator" do
        let(:filtered_columns) { filters.map { to_filter(_1) } }
        let(:filters) { [['drop_down_list', { operator: 'match', value: ['Dessert', 'Fromage'] }]] }

        let(:types_de_champ_public) do
          [
            { type: :drop_down_list, libelle: 'drop_down_list', options: ['Fromage', 'Dessert', 'Chocolat'] },
          ]
        end

        let(:kept_dossier) { create(:dossier, procedure:) }
        let(:kept_dossier_2) { create(:dossier, procedure:) }
        let(:discarded_dossier) { create(:dossier, procedure:) }

        before do
          kept_dossier.champs.first.update!(value: 'Fromage')
          kept_dossier_2.champs.first.update!(value: 'Dessert')
          discarded_dossier.champs.first.update!(value: 'Chocolat')
        end

        it { is_expected.to contain_exactly(kept_dossier.id, kept_dossier_2.id) }
      end
    end

    context 'for type_de_champ_private table' do
      let(:filter) { [type_de_champ_private.libelle, 'keep'] }

      let(:kept_dossier) { create(:dossier, procedure:) }
      let(:discarded_dossier) { create(:dossier, procedure:) }
      let(:type_de_champ_private) { procedure.active_revision.types_de_champ_private.first }

      before do
        kept_dossier.champs.find_by(stable_id: type_de_champ_private.stable_id).update(value: 'keep me')
        discarded_dossier.champs.find_by(stable_id: type_de_champ_private.stable_id).update(value: 'discard me')
      end

      it { is_expected.to contain_exactly(kept_dossier.id) }
    end

    context 'for type_de_champ using AddressableColumnConcern' do
      let(:column) { filtered_columns.first.column }
      let(:types_de_champ_public) { [{ type: :rna, stable_id: 1, libelle: 'rna' }] }
      let(:type_de_champ) { procedure.active_revision.types_de_champ.first }
      let(:kept_dossier) { create(:dossier, procedure:) }

      context "when searching by postal_code (text)" do
        let(:value) { "60580" }
        let(:filter) { ["rna – Code postal (5 chiffres)", value] }

        before do
          kept_dossier.project_champs_public.find { _1.stable_id == 1 }.update(value_json: { "postal_code" => value })
          create(:dossier, procedure:).project_champs_public.find { _1.stable_id == 1 }.update(value_json: { "postal_code" => "unknown" })
        end

        it { is_expected.to contain_exactly(kept_dossier.id) }

        it 'describes column' do
          expect(column.type).to eq(:text)
          expect(column.options_for_select).to eq([])
        end
      end

      context "when searching by departement_code (enum)" do
        let(:value) { "99" }
        let(:filter) { ["rna – Département", value] }

        before do
          kept_dossier.project_champs_public.find { _1.stable_id == 1 }.update(value_json: { "department_code" => value })
          create(:dossier, procedure:).project_champs_public.find { _1.stable_id == 1 }.update(value_json: { "department_code" => "unknown" })
        end

        it { is_expected.to contain_exactly(kept_dossier.id) }

        it 'describes column' do
          expect(column.type).to eq(:enum)
          expect(column.options_for_select.first).to eq(["01 – Ain", "01"])
        end
      end

      context "when searching by region_name" do
        let(:value) { "60" }
        let(:filter) { ["rna – Région", value] }

        before do
          kept_dossier.project_champs_public.find { _1.stable_id == 1 }.update(value_json: { "region_name" => value })
          create(:dossier, procedure:).project_champs_public.find { _1.stable_id == 1 }.update(value_json: { "region_name" => "unknown" })
        end

        it { is_expected.to contain_exactly(kept_dossier.id) }

        it 'describes column' do
          expect(column.type).to eq(:enum)
          expect(column.options_for_select.first).to eq(["Auvergne-Rhône-Alpes", "84"])
        end
      end
    end

    context 'for etablissement table' do
      context 'for entreprise_date_creation column' do
        let(:filter) { ['Entreprise date de création', '21/6/2018'] }

        let!(:kept_dossier) { create(:dossier, procedure:, etablissement: create(:etablissement, entreprise_date_creation: Time.zone.local(2018, 6, 21))) }
        let!(:discarded_dossier) { create(:dossier, procedure:, etablissement: create(:etablissement, entreprise_date_creation: Time.zone.local(2008, 6, 21))) }

        it { is_expected.to contain_exactly(kept_dossier.id) }

        context 'with multiple search values' do
          let(:filters) { [['Entreprise date de création', '21/6/2016'], ['Entreprise date de création', '21/6/2018']] }

          let!(:other_kept_dossier) { create(:dossier, procedure:, etablissement: create(:etablissement, entreprise_date_creation: Time.zone.local(2016, 6, 21))) }

          it 'returns every dossier that matches any of the search criteria for a given column' do
            is_expected.to contain_exactly(kept_dossier.id, other_kept_dossier.id)
          end
        end
      end

      context 'for code_postal column' do
        # All columns except entreprise_date_creation work exacly the same, just testing one

        let(:filter) { ['Établissement code postal', '75017'] }

        let!(:kept_dossier) { create(:dossier, procedure:, etablissement: create(:etablissement, code_postal: '75017')) }
        let!(:discarded_dossier) { create(:dossier, procedure:, etablissement: create(:etablissement, code_postal: '25000')) }

        it { is_expected.to contain_exactly(kept_dossier.id) }

        context 'with multiple search values' do
          let(:filters) { [['Établissement code postal', '75017'], ['Établissement code postal', '88100']] }

          let!(:other_kept_dossier) { create(:dossier, procedure:, etablissement: create(:etablissement, code_postal: '88100')) }

          it 'returns every dossier that matches any of the search criteria for a given column' do
            is_expected.to contain_exactly(kept_dossier.id, other_kept_dossier.id)
          end
        end
      end
    end

    context 'for user table' do
      let(:filter) { ['Demandeur', 'keepmail'] }

      let!(:kept_dossier) { create(:dossier, procedure:, user: create(:user, email: 'me@keepmail.com')) }
      let!(:discarded_dossier) { create(:dossier, procedure:, user: create(:user, email: 'me@discard.com')) }

      it { is_expected.to contain_exactly(kept_dossier.id) }

      context 'with multiple search values' do
        let(:filters) { [['Demandeur', 'keepmail'], ['Demandeur', 'beta.gouv.fr']] }

        let!(:other_kept_dossier) { create(:dossier, procedure:, user: create(:user, email: 'bazinga@beta.gouv.fr')) }

        it 'returns every dossier that matches any of the search criteria for a given column' do
          is_expected.to contain_exactly(kept_dossier.id, other_kept_dossier.id)
        end
      end
    end

    context 'for individual table' do
      let(:procedure) { create(:procedure, :for_individual) }
      let!(:kept_dossier) { create(:dossier, procedure:, individual: build(:individual, gender: 'Mme', prenom: 'Josephine', nom: 'Baker')) }
      let!(:discarded_dossier) { create(:dossier, procedure:, individual: build(:individual, gender: 'M', prenom: 'Jean', nom: 'Tremblay')) }

      context 'for gender column' do
        before do
          procedure.update!(no_gender: false)
        end

        let(:filter) { ['Civilité', 'Mme'] }

        it { is_expected.to contain_exactly(kept_dossier.id) }
      end

      context 'for prenom column' do
        let(:filter) { ['Prénom', 'Josephine'] }

        it { is_expected.to contain_exactly(kept_dossier.id) }
      end

      context 'for nom column' do
        let(:filter) { ['Nom', 'Baker'] }

        it { is_expected.to contain_exactly(kept_dossier.id) }
      end

      context 'with multiple search values' do
        let(:filters) { [['Prénom', 'Josephine'], ['Prénom', 'Romuald']] }

        let!(:other_kept_dossier) { create(:dossier, procedure:, individual: build(:individual, gender: 'M', prenom: 'Romuald', nom: 'Pistis')) }

        it 'returns every dossier that matches any of the search criteria for a given column' do
          is_expected.to contain_exactly(kept_dossier.id, other_kept_dossier.id)
        end
      end
    end

    context 'for followers_instructeurs table' do
      let(:filter) { ['Instructeurs', 'keepmail'] }

      let!(:kept_dossier) { create(:dossier, procedure:) }
      let!(:discarded_dossier) { create(:dossier, procedure:) }

      before do
        create(:follow, dossier: kept_dossier, instructeur: create(:instructeur, email: 'me@keepmail.com'))
        create(:follow, dossier: discarded_dossier, instructeur: create(:instructeur, email: 'me@discard.com'))
      end

      it { is_expected.to contain_exactly(kept_dossier.id) }

      context 'with multiple search values' do
        let(:filters) { [['Instructeurs', 'keepmail'], ['Instructeurs', 'beta.gouv.fr']] }

        let(:other_kept_dossier) { create(:dossier, procedure:) }

        before do
          create(:follow, dossier: other_kept_dossier, instructeur: create(:instructeur, email: 'bazinga@beta.gouv.fr'))
        end

        it 'returns every dossier that matches any of the search criteria for a given column' do
          is_expected.to contain_exactly(kept_dossier.id, other_kept_dossier.id)
        end
      end
    end

    context 'for traitements table' do
      let(:filter) { ["Adresse électronique d’un des agents ayant pris part a l’instruction du dossier", 'keepmail'] }

      let!(:kept_dossier) { create(:dossier, procedure:) }
      let!(:discarded_dossier) { create(:dossier, procedure:) }

      before do
        create(:traitement, dossier: kept_dossier, instructeur_email: 'me@keepmail.com')
        create(:traitement, dossier: discarded_dossier, instructeur_email: 'me@discard.com')
      end

      it { is_expected.to contain_exactly(kept_dossier.id) }

      context 'with multiple search values' do
        let(:filters) { [["Adresse électronique d’un des agents ayant pris part a l’instruction du dossier", 'keepmail'], ["Adresse électronique d’un des agents ayant pris part a l’instruction du dossier", 'beta.gouv.fr']] }

        let!(:other_kept_dossier) { create(:dossier, procedure:) }

        before do
          create(:traitement, dossier: other_kept_dossier, instructeur_email: 'bazinga@beta.gouv.fr')
        end

        it 'returns every dossier that matches any of the search criteria for a given column' do
          is_expected.to contain_exactly(kept_dossier.id, other_kept_dossier.id)
        end
      end
    end

    context 'for groupe_instructeur table' do
      let(:filter) { ['Groupe instructeur', procedure.defaut_groupe_instructeur.id.to_s] }

      let!(:gi_2) { create(:groupe_instructeur, label: 'gi2', procedure:) }
      let!(:gi_3) { create(:groupe_instructeur, label: 'gi3', procedure:) }

      let!(:kept_dossier) { create(:dossier, :en_construction, procedure:) }
      let!(:discarded_dossier) { create(:dossier, :en_construction, procedure:, groupe_instructeur: gi_2) }

      it { is_expected.to contain_exactly(kept_dossier.id) }

      context 'with multiple search values' do
        let(:filters) { [['Groupe instructeur', procedure.defaut_groupe_instructeur.id.to_s], ['Groupe instructeur', gi_3.id.to_s]] }

        let!(:other_kept_dossier) { create(:dossier, procedure:, groupe_instructeur: gi_3) }

        it 'returns every dossier that matches any of the search criteria for a given column' do
          is_expected.to contain_exactly(kept_dossier.id, other_kept_dossier.id)
        end
      end
    end

    context 'with a buggy filter, for instance a text in a integer column' do
      let(:filter) { ['N° dossier', 'buggy'] }

      it { is_expected.to be_empty }
    end

    context 'with a json structured filter' do
      context 'with a single value' do
        let(:types_de_champ_public) { [{ type: :yes_no, libelle: 'yes_no' }] }
        let(:filter) { ['yes_no', { operator: 'match', value: ['true'] }] }

        let(:kept_dossier) { create(:dossier, procedure:) }
        let(:discarded_dossier) { create(:dossier, procedure:) }

        before do
          kept_dossier.champs.first.update!(value: 'true')
          discarded_dossier.champs.first.update!(value: 'false')
        end

        it { is_expected.to contain_exactly(kept_dossier.id) }
      end
    end
  end

  describe '.normalize_filter' do
    subject { described_class.send(:normalize_filter, filter) }

    context 'when filter is a string (old filter)' do
      let(:filter) { 'test_value' }

      it 'wraps the string in a hash with value key' do
        expect(subject).to eq({ operator: 'match', value: ['test_value'] })
      end
    end

    context 'when filter is a hash with only value key' do
      let(:filter) { { value: 'test_value' } }

      it 'returns the filter value in an array' do
        expect(subject).to eq({ operator: 'match', value: ['test_value'] })
      end
    end

    context 'when filter has operator and values' do
      let(:filter) { { operator: 'match', value: ['a', 'b'] } }

      it 'returns the filter as is' do
        expect(subject).to eq({ operator: 'match', value: ['a', 'b'] })
      end
    end
  end

  describe '.group_filters' do
    let(:procedure) { create(:procedure) }
    let(:column1) { procedure.find_column(label: 'État du dossier') }
    let(:column2) { procedure.find_column(label: 'Date de création') }

    subject { described_class.send(:group_filters, filtered_columns) }

    context 'with single filter per column' do
      let(:filtered_columns) do
        [
          FilteredColumn.new(column: column1, filter: { operator: 'match', value: 'en_construction' }),
          FilteredColumn.new(column: column2, filter: { operator: 'match', value: '2025-01-01' }),
        ]
      end

      it 'groups filters by column and operator and normalizes them' do
        expected = {
          [column1, "match"] => [{ operator: 'match', value: ['en_construction'] }],
          [column2, "match"] => [{ operator: 'match', value: ['2025-01-01'] }],
        }
        expect(subject).to eq(expected)
      end
    end

    context 'with multiple filters for the same column' do
      let(:filtered_columns) do
        [
          FilteredColumn.new(column: column1, filter: { operator: 'match', value: ['en_construction'] }),
          FilteredColumn.new(column: column1, filter: { operator: 'match', value: ['en_instruction'] }),
        ]
      end

      it 'groups multiple filters by column and normalizes them' do
        expected = {
          [column1, "match"] => [
            { operator: 'match', value: ['en_construction', 'en_instruction'] },
          ],
        }
        expect(subject).to eq(expected)
      end
    end

    context 'with multiple match filters for the same column' do
      let(:filtered_columns) do
        [
          FilteredColumn.new(column: column1, filter: { operator: 'match', value: ['a'] }),
          FilteredColumn.new(column: column1, filter: { operator: 'match', value: ['b', 'a'] }),
        ]
      end

      it 'merges their values' do
        expected = {
          [column1, "match"] => [
            { operator: 'match', value: ['a', 'b'] },
          ],
        }

        expect(subject).to eq(expected)
      end
    end

    context 'with hash filters' do
      let(:filtered_columns) do
        [
          FilteredColumn.new(column: column1, filter: { operator: 'match', value: ['en_construction'] }),
          FilteredColumn.new(column: column1, filter: { operator: 'match', value: ['en_instruction'] }),
        ]
      end

      it 'groups filters by column and operator' do
        expected = {
          [column1, "match"] => [{ operator: 'match', value: ['en_construction', 'en_instruction'] }],
        }
        expect(subject).to eq(expected)
      end
    end

    context 'with not mergeable filters' do
      let(:filtered_columns) do
        [
          FilteredColumn.new(column: column1, filter: { operator: 'match', value: ['a', 'b'] }),
          FilteredColumn.new(column: column1, filter: { operator: 'before', value: ['2025-01-01'] }),
        ]
      end

      it 'groups filters by column and operator' do
        expected = {
          [column1, "match"] => [{ operator: 'match', value: ['a', 'b'] }],
          [column1, "before"] => [{ operator: 'before', value: ['2025-01-01'] }],
        }
        expect(subject).to eq(expected)
      end
    end
  end

  describe '.merge_match_filters' do
    subject { described_class.send(:merge_match_filters, filters) }

    context 'when match filters' do
      let(:filters) do
        [
          { operator: 'match', value: ['Dessert'] },
          { operator: 'match', value: ['Fromage'] },
        ]
      end

      it 'groups values by operator' do
        expected = [
          {
            operator: 'match',
            value: ['Dessert', 'Fromage'],
          },
        ]
        expect(subject).to eq(expected)
      end
    end

    context 'when not match filters' do
      let(:filters) do
        [
          { operator: 'before', value: ['2025-01-01'] },
          { operator: 'before', value: ['2025-01-02'] },
        ]
      end

      it 'does not merge values' do
        expect(subject).to eq(filters)
      end
    end
  end
end
