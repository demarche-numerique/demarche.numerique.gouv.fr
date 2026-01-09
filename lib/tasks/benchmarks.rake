# frozen_string_literal: true

namespace :benchmarks do
  desc 'Benchmark exports'
  task exports: :environment do
    p_45964 = Procedure.find(45964)
    p_55824 = Procedure.find(55824)
    Benchmark.bm do |x|
      x.report("Démarche 45964") { ProcedureExportService.new(p_45964, p_45964.dossiers, p_45964.administrateurs.first).to_xlsx }
      x.report("Démarche 55824") { ProcedureExportService.new(p_55824, p_55824.dossiers, p_55824.administrateurs.first).to_xlsx }
    end
  end

  desc 'Benchmark graphql'
  task graphql: :environment do
    p_45964 = Procedure.find(45964)
    p_55824 = Procedure.find(55824)
    Benchmark.bm do |x|
      x.report("Démarche 45964") { SerializerService.dossiers(p_45964) }
      x.report("Démarche 55824") { SerializerService.dossiers(p_55824) }
      x.report("Démarches publiques") { SerializerService.demarches_publiques }
    end
  end

  desc 'Benchmark pdf'
  task pdf: :environment do
    p_45964 = Procedure.find(45964)
    p_55824 = Procedure.find(55824)
    Benchmark.bm do |x|
      x.report("Démarche 45964") { PiecesJustificativesService.new(user_profile: p_45964.administrateurs.first).generate_dossiers_export(p_45964.dossiers) }
      x.report("Démarche 55824") { PiecesJustificativesService.new(user_profile: p_55824.administrateurs.first).generate_dossiers_export(p_55824.dossiers.limit(10_000)) }
    end
  end

  desc 'Attestation Template parser'
  task attestation_template_parser: :environment do
    procedure = Procedure.find(68139)
    Benchmark.bm do |x|
      x.report("Empty") { TagsSubstitutionConcern::TagsParser.parse('') }
      x.report("Démarche 68139") { TagsSubstitutionConcern::TagsParser.parse(procedure.attestation_acceptation_template.body) }
    end
  end

  # Benchmark une action Rails spécifique, y compris le temps de génération des views.
  # Optionnellement, compare avec une autre implémentation de l’action
  # sur la même branche ou sur deux branches git.
  #
  # Le benchmark se fait en deux temps (2 processes ruby séparés à lancer l’un après l’autre)
  # en stockant les résultats intermédiaires dans un fichier.
  #
  # === Prérequis ===
  #
  # 1. On fake l’authentification. Commenter le `before_action :authenticate_*` concerné
  #
  # 2. Override dans le controller le(s) `current_*` concernés
  #
  #    Par exemple :
  #
  #    def current_instructeur
  #      @current_instructeur ||= Instructeur.find(12_345)
  #    end
  #
  # 3. Pour se rapprocher un peu plus de l’environnement de prod, activer le cache:
  #    `rails dev:cache` puis redémarrer le serveur (à refaire à la fin pour l’enlever)
  #
  # 4a. Pour comparer l’implémentation de deux actions sur la même branche (par ex `index` et `index_main`):
  #    la seconde implémentation doit :
  #    - avoir une route définie (ie. `get :index_main`)
  #    - adapter les `before_action`
  #    - la conclure par `render :index` si la vue est identique, ou adapter les vues.
  #
  #    Exécuter 2 foix:
  #
  #    rake benchmarks:action[Instructeurs::ProceduresController,index,index_main]
  #
  # 4b. Pour comparer l’implémentation d’une même action sur 2 branches,
  #     exécuter sur chacune d’entre elle :
  #
  #     rake benchmarks:action[Instructeurs::ProceduresController,index,index]
  #
  #     Attention : penser à refaire les étapes 1 et 2 sur la seconde branche !
  #
  # 5.  Pour passer des paramètres d’urls, utiliser la variable d’environnement `PARAMS`
  #     sous forme key=value, séparables par des virgules :
  #
  #     rake benchmarks:action[Users::CommencerController,commencer,commencer] PARAMS=path=my-demarche,other=value
  #
  desc "Benchmark a Rails action"
  task :action, [:controller, :action1, :action2] => :environment do |_, args|
    require 'benchmark/ips'

    controller_class = args[:controller].constantize
    action1_name = args[:action1]
    action2_name = args[:action2]

    warden_mock = Struct.new(:user) do
      def authenticate(*_args); end
    end

    warden = warden_mock.new(nil)

    setup_controller_instance = Proc.new do |controller_class, warden|
      controller = controller_class.new
      controller.request = ActionDispatch::TestRequest.create
      controller.response = ActionDispatch::TestResponse.new
      controller.request.env['warden'] = warden
      # controller.request.path_parameters[:format] = 'pdf'

      params = ENV.fetch("PARAMS") { "" }.split(",")
      params.each do |param|
        key, value = param.split("=")
        controller.params[key.strip] = value.strip
      end

      controller
    end

    Benchmark.ips do |x|
      x.config(time: 30, warmup: 10)
      x.hold! 'tmp/benchmarks_action_hold' # run in different processes so we can switch branches

      x.report("#{controller_class}##{action1_name}1") do
        controller = setup_controller_instance.call(controller_class, warden)
        controller.process(action1_name)
      end

      if action2_name
        x.report("#{controller_class}##{action2_name}2") do
          controller = setup_controller_instance.call(controller_class, warden)
          controller.process(action2_name)
        end
      end

      x.compare!
    end
  end

  desc 'Benchmark ProcedureRevisionPreloader.load_one'
  task procedure_revision_preloader: :environment do
    revision_ids = ProcedureRevision.order('RANDOM()').limit(100).pluck(:id)
    all_revisions = ProcedureRevision.where(id: revision_ids).includes(:procedure)

    Benchmark.bm do |x|
      x.report("load_one (#{all_revisions.count} revisions) without includes") do
        all_revisions.each do |revision|
          ProcedureRevisionPreloader.load_one(revision)
        end
      end

      x.report("load_one (#{all_revisions.count} revisions) with includes (old way)") do
        all_revisions.each do |revision|
          revisions = [revision]

          revisions_by_id = revisions.index_by(&:id)

          coordinates_by_revision_id = ProcedureRevisionTypeDeChamp
            .where(revision_id: revisions.map(&:id))
            .includes(type_de_champ: { notice_explicative_attachment: :blob, piece_justificative_template_attachment: :blob })
            .order(:position, :id)
            .to_a
            .group_by(&:revision_id)

          coordinates_by_revision_id.each_pair do |revision_id, coordinates|
            revision = revisions_by_id[revision_id]

            coordinates.each do |coordinate|
              coordinate.association(:revision).target = revision
              coordinate.association(:procedure).target = revision.procedure
            end
          end

          revisions_by_id.each_pair do |revision_id, revision|
            revision.association(:revision_types_de_champ).target = coordinates_by_revision_id[revision_id] || []
          end
        end
      end
    end
  end

  desc "Inspect possible memory leaks"
  task inspect_memory_leak: :environment do
    10.times do
      10_000.times do
        # Write code here
      end

      puts `ps -o rss= -p #{$$}`
    end
  end
end
