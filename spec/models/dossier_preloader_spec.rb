# frozen_string_literal: true

describe DossierPreloader do
  let(:type_de_champs) do
    [
      { type: :text },
      { type: :repetition, mandatory: true, children: [{ type: :text }] },
      { type: :repetition, mandatory: false, children: [{ type: :text }] },
    ]
  end
  let(:procedure) { create(:procedure, public_type_de_champs: type_de_champs) }
  let(:dossier) { create(:dossier, procedure: procedure) }
  let(:repetition) { subject.root_champs_public.second }
  let(:repetition_optional) { subject.root_champs_public.third }
  let(:first_child) { repetition.rows.first.first }

  describe 'all' do
    subject { DossierPreloader.load_one(dossier, pj_template: true) }

    before { subject }

    it do
      count = 0

      callback = lambda { |*_args| count += 1 }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        expect(subject.id).to eq(dossier.id)
        expect(subject.root_champs_public.size).to eq(type_de_champs.size)
        expect(subject.changed?).to be false

        expect(first_child.type).to eq('Champs::TextChamp')
        expect(repetition).not_to eq(first_child)
        expect(subject.champ_data.first.dossier).to eq(subject)
        expect(subject.champ_data.find(&:public?).dossier).to eq(subject)
        expect(subject.root_champs_public.first.dossier).to eq(subject)

        expect(subject.root_champs_public.first.type_de_champ.piece_justificative_template.attached?).to eq(false)

        expect(subject.champ_data.first.conditional?).to eq(false)
        expect(subject.champ_data.find(&:public?).conditional?).to eq(false)
        expect(subject.root_champs_public.first.conditional?).to eq(false)

        expect(repetition.rows.first.first.public_id).to eq(first_child.public_id)
        expect(repetition_optional.row_ids).to be_empty
      end

      expect(count).to eq(0)
    end
  end

  describe 'all with revisions already loaded' do
    let!(:dossiers) { [create(:dossier, procedure:)] }

    def sql_touching(table, &block)
      queries = []
      callback = lambda { |*args| queries << args.last[:sql] if args.last[:sql].include?(table) }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &block)
      queries
    end

    it 'reuses revisions loaded with their types de champ instead of loading them again' do
      loaded_dossiers = Dossier.where(id: dossiers).for_api_v2.to_a

      expect(sql_touching('procedure_revision') { DossierPreloader.new(loaded_dossiers).all }).to be_empty

      loaded_dossier = loaded_dossiers.first
      expect(loaded_dossier.revision.association(:procedure)).to be_loaded
      expect(sql_touching('') { loaded_dossier.root_champs_public.map(&:type_de_champ) }).to be_empty
    end

    it 'loads revisions that are missing or loaded without their types de champ' do
      loaded_dossiers = Dossier.where(id: dossiers).includes(:revision).to_a

      queries = sql_touching('"procedure_revision_types_de_champ"') { DossierPreloader.new(loaded_dossiers).all }

      expect(queries.size).to eq(1)
      expect(sql_touching('') { loaded_dossiers.first.root_champs_public.map(&:type_de_champ) }).to be_empty
    end
  end

  describe '#in_batches (preloading for PDF/zip export)' do
    let(:instructeur) { create(:instructeur) }
    let(:expert) { experts.default }
    let(:experts_procedure) { experts_procedures.default }
    let(:procedure) { create(:procedure, :published, :for_individual, instructeurs: [instructeur]) }

    let!(:dossiers) do
      Array.new(3) do
        dossier = create(:dossier, :en_instruction, :with_individual, procedure:)

        create(:traitement, dossier:, state: :en_instruction)
        create(:commentaire, dossier:, instructeur:)
        create(:commentaire, dossier:, expert:)
        create(:avis, dossier:, claimant: instructeur, experts_procedure:)

        correction_commentaire = create(:commentaire, dossier:, instructeur:)
        create(:dossier_correction, :resolved, dossier:, commentaire: correction_commentaire)

        dossier
      end
    end

    it 'preloads associations for PDF export without N+1' do
      all_dossiers = Dossier.where(id: dossiers.map(&:id))
      loaded_dossiers = []

      DossierPreloader.new(all_dossiers).in_batches(includes: DossierPreloader::PJ_EXPORT_INCLUDES) do |batch|
        loaded_dossiers = batch
      end

      count = 0
      callback = lambda { |*_args| count += 1 }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        loaded_dossiers.each do |dossier|
          # Access associations that are used in PDF export
          expect(dossier.individual).to be_present
          expect(dossier.traitement).to be_present
          expect(dossier.association(:pending_corrections).loaded?).to be true
          expect(dossier.commentaires).to be_present
          dossier.commentaires.each do |c|
            c.instructeur&.email
            c.expert&.email
          end
          expect(dossier.avis).to be_present
          dossier.avis.each do |a|
            a.expert&.email
          end
        end
      end

      expect(count).to eq(0)
    end
  end

  describe '#in_batches (streamed, ordered for sheet export)' do
    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:procedure, :published, :for_individual, instructeurs: [instructeur]) }

    let!(:dossiers) do
      [3.days.ago, 1.day.ago, 2.days.ago].map do |depose_at|
        dossier = create(:dossier, :en_instruction, :with_individual, procedure:)
        dossier.update_column(:depose_at, depose_at)
        create(:groupe_instructeur, label: 'gi', procedure:) if dossier == nil # noop, just to ensure procedure has gi
        dossier
      end
    end

    let(:dossier_includes) do
      [
        :user,
        :individual,
        :followers_instructeurs,
        :traitement,
        :groupe_instructeur,
        :etablissement,
        :pending_corrections,
        { procedure: [:groupe_instructeurs] },
        { avis: [:claimant, :expert] },
      ]
    end

    it 'yields dossiers in depose_at order across batches without materializing all dossiers' do
      all_dossiers = procedure.dossiers
      yielded = []

      DossierPreloader.new(all_dossiers.ordered_for_export).in_batches(includes: dossier_includes) do |batch|
        yielded.concat(batch)
      end

      expect(yielded.map(&:id)).to eq(all_dossiers.ordered_for_export.pluck(:id))
    end

    it 'preloads requested includes (no N+1 inside the block)' do
      all_dossiers = procedure.dossiers

      DossierPreloader.new(all_dossiers.ordered_for_export).in_batches(includes: dossier_includes) do |batch|
        count = 0
        callback = lambda { |*_args| count += 1 }
        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          batch.each do |dossier|
            dossier.user&.email
            dossier.individual&.gender
            dossier.traitement&.processed_at
            dossier.groupe_instructeur&.label
            dossier.etablissement&.siret
            dossier.procedure.groupe_instructeurs.to_a
            dossier.followers_instructeurs.to_a
            dossier.avis.each { |a| a.claimant&.email; a.expert&.email }
            dossier.pending_corrections.to_a
            dossier.champ_data.to_a # champs préchargés via load_dossiers
          end
        end
        expect(count).to eq(0)
      end
    end
  end
end
