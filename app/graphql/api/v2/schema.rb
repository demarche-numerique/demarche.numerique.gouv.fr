# frozen_string_literal: true

class API::V2::Schema < GraphQL::Schema
  default_max_page_size 100
  default_page_size 100
  # Connection fields multiply their child complexity by the requested page size, so a
  # full page (first: 100) of our richest query is expensive by design:
  #   - getDossier (single dossier, all includes): ~430
  #   - getDemarche dossiers(first: 100), all includes on: ~37 600  <- legitimate ceiling
  # The budget is set to ~1.6x that ceiling: enough headroom for schema growth and the
  # heaviest legitimate query, while rejecting the real abuse vector (aliasing several
  # full-page connections into one request, e.g. 2x the canonical query ~= 75 000).
  # GRAPHQL_MAX_COMPLEXITY overrides it without a release if a legitimate integration
  # ever trips it: raise it, or set it to 0 to lift the limit entirely.
  DEFAULT_MAX_COMPLEXITY = 60_000
  MAX_COMPLEXITY = ENV['GRAPHQL_MAX_COMPLEXITY'].presence&.to_i || DEFAULT_MAX_COMPLEXITY
  max_complexity MAX_COMPLEXITY.nonzero?
  max_depth 15

  query Types::QueryType
  mutation Types::MutationType

  context_class API::V2::Context

  def self.id_from_object(object, type_definition, ctx)
    if type_definition == Types::DemarcheDescriptorType
      (object.is_a?(Procedure) ? object : object.procedure).to_typed_id
    elsif type_definition == Types::DeletedDossierType
      object.is_a?(DeletedDossier) ? object.to_typed_id : GraphQL::Schema::UniqueWithinType.encode('DeletedDossier', object.id)
    elsif object.is_a?(Hash)
      object[:id]
    elsif object.is_a?(Column)
      GraphQL::Schema::UniqueWithinType.encode('Column', object.h_id.fetch(:column_id))
    else
      object.to_typed_id
    end
  end

  def self.object_from_id(id, ctx)
    ApplicationRecord.record_from_typed_id(id)
  end

  def self.resolve_type(type_definition, object, ctx)
    case object
    when Procedure
      if type_definition == Types::DemarcheDescriptorType
        type_definition
      else
        Types::DemarcheType
      end
    when Dossier
      Types::DossierType
    when Commentaire
      Types::MessageType
    when Instructeur, User, Expert
      Types::ProfileType
    when Individual
      Types::PersonnePhysiqueType
    when Etablissement
      Types::PersonneMoraleType
    when GroupeInstructeur
      Types::GroupeInstructeurType
    when Webhook
      Types::WebhookType
    else
      type_definition
    end
  end

  orphan_types Types::Champs::AddressChampType,
    Types::Champs::CarteChampType,
    Types::Champs::CheckboxChampType,
    Types::Champs::CiviliteChampType,
    Types::Champs::CommuneChampType,
    Types::Champs::DateChampType,
    Types::Champs::DatetimeChampType,
    Types::Champs::DecimalNumberChampType,
    Types::Champs::DepartementChampType,
    Types::Champs::DossierLinkChampType,
    Types::Champs::EpciChampType,
    Types::Champs::RNAChampType,
    Types::Champs::RNFChampType,
    Types::Champs::IntegerNumberChampType,
    Types::Champs::LinkedDropDownListChampType,
    Types::Champs::MultipleDropDownListChampType,
    Types::Champs::PaysChampType,
    Types::Champs::PieceJustificativeChampType,
    Types::Champs::RegionChampType,
    Types::Champs::RepetitionChampType,
    Types::Champs::SiretChampType,
    Types::Champs::TextChampType,
    Types::Champs::TitreIdentiteChampType,
    Types::Champs::EngagementJuridiqueChampType,
    Types::Champs::YesNoChampType,
    Types::Champs::DropDownListChampType,
    Types::Champs::HeaderSectionChampType,
    Types::Champs::ExplicationChampType,
    Types::GeoAreas::ParcelleCadastraleType,
    Types::GeoAreas::SelectionUtilisateurType,
    Types::GeoAreas::RpgType,
    Types::PersonneMoraleType,
    Types::PersonneMoraleIncompleteType,
    Types::PersonnePhysiqueType,
    Types::Champs::Descriptor::AddressChampDescriptorType,
    Types::Champs::Descriptor::AnnuaireEducationChampDescriptorType,
    Types::Champs::Descriptor::CarteChampDescriptorType,
    Types::Champs::Descriptor::CheckboxChampDescriptorType,
    Types::Champs::Descriptor::CiviliteChampDescriptorType,
    Types::Champs::Descriptor::COJOChampDescriptorType,
    Types::Champs::Descriptor::CommuneChampDescriptorType,
    Types::Champs::Descriptor::DateChampDescriptorType,
    Types::Champs::Descriptor::DatetimeChampDescriptorType,
    Types::Champs::Descriptor::DecimalNumberChampDescriptorType,
    Types::Champs::Descriptor::DepartementChampDescriptorType,
    Types::Champs::Descriptor::DossierLinkChampDescriptorType,
    Types::Champs::Descriptor::DropDownListChampDescriptorType,
    Types::Champs::Descriptor::EmailChampDescriptorType,
    Types::Champs::Descriptor::EpciChampDescriptorType,
    Types::Champs::Descriptor::ExplicationChampDescriptorType,
    Types::Champs::Descriptor::HeaderSectionChampDescriptorType,
    Types::Champs::Descriptor::IbanChampDescriptorType,
    Types::Champs::Descriptor::IntegerNumberChampDescriptorType,
    Types::Champs::Descriptor::LinkedDropDownListChampDescriptorType,
    Types::Champs::Descriptor::MultipleDropDownListChampDescriptorType,
    Types::Champs::Descriptor::NumberChampDescriptorType,
    Types::Champs::Descriptor::PaysChampDescriptorType,
    Types::Champs::Descriptor::PhoneChampDescriptorType,
    Types::Champs::Descriptor::PieceJustificativeChampDescriptorType,
    Types::Champs::Descriptor::RegionChampDescriptorType,
    Types::Champs::Descriptor::RepetitionChampDescriptorType,
    Types::Champs::Descriptor::RNAChampDescriptorType,
    Types::Champs::Descriptor::RNFChampDescriptorType,
    Types::Champs::Descriptor::SiretChampDescriptorType,
    Types::Champs::Descriptor::TextareaChampDescriptorType,
    Types::Champs::Descriptor::TextChampDescriptorType,
    Types::Champs::Descriptor::TitreIdentiteChampDescriptorType,
    Types::Champs::Descriptor::YesNoChampDescriptorType,
    Types::Champs::Descriptor::ReferentielChampDescriptorType,
    Types::Champs::Descriptor::FormattedChampDescriptorType,
    Types::Champs::Descriptor::EngagementJuridiqueChampDescriptorType,
    Types::Champs::Descriptor::QuotientFamilialChampDescriptorType,
    Types::Champs::Descriptor::PreRempliChampDescriptorType,
    Types::Champs::Descriptor::EtudiantBoursierChampDescriptorType,
    Types::Champs::Descriptor::AAHChampDescriptorType,
    Types::Champs::Descriptor::AEEHChampDescriptorType,
    Types::Champs::Descriptor::ARSChampDescriptorType,
    Types::Columns::AttachmentsColumnType,
    Types::Columns::BooleanColumnType,
    Types::Columns::DateColumnType,
    Types::Columns::DateTimeColumnType,
    Types::Columns::DecimalColumnType,
    Types::Columns::EnumColumnType,
    Types::Columns::EnumsColumnType,
    Types::Columns::IntegerColumnType,
    Types::Columns::TextColumnType,
    Types::Columns::GeoJSONColumnType

  def self.unauthorized_object(error)
    # Add a top-level error to the response instead of returning nil:
    raise GraphQL::ExecutionError.new("An object of type #{error.type.graphql_name} was hidden due to permissions", extensions: { code: :unauthorized })
  end

  def self.type_error(error, ctx)
    # An out-of-bounds Int in the request (e.g. a SIRET sent as demarche number) is a
    # client input error: surface it as a validation error instead of a 500.
    if error.is_a?(GraphQL::IntegerDecodingError)
      raise GraphQL::ExecutionError.new(error.message, extensions: { code: :bad_request })
    end

    # An unparsable Date argument (e.g. free text sent to an annotation date) is a client
    # input error too, and the default handler already turns it into a proper validation
    # error for the client. Only the Sentry report is wrong: the message embeds the
    # offending value, so one defect was split into a new issue per distinct bad date.
    return super if error.is_a?(GraphQL::DateEncodingError)

    # Capture type errors in Sentry. Thouse errors are our responsability and usually linked to
    # instances of "bad data".
    if error.is_a?(GraphQL::InvalidNullError)
      # Relay mutation payload classes are anonymous, so the error class name
      # (#<Class:0x...>::InvalidNullError) varies per process and Sentry splits one
      # defect into many issues; group by message instead.
      Sentry.capture_exception(error, extra: ctx.query_info, fingerprint: ['GraphQL::InvalidNullError', error.message])

      execution_error = GraphQL::ExecutionError.new(error.message, ast_node: error.ast_node, extensions: { code: :invalid_null })
      execution_error.path = ctx[:current_path]
      ctx.errors << execution_error
    else
      Sentry.capture_exception(error, extra: ctx.query_info)
      super
    end
  end

  rescue_from(ActiveRecord::RecordNotFound) do |_error, _object, _args, _ctx, field|
    raise GraphQL::ExecutionError.new("#{field.type.unwrap.graphql_name} not found", extensions: { code: :not_found })
  end

  class Timeout < GraphQL::Schema::Timeout
    # The ceiling below bounds an interactive HTTP request. SerializerService runs this
    # same schema from cron jobs — notably the datagouv export, which paginates over every
    # public procedure — where interrupting a page only yields a truncated export. Give
    # those a batch-sized budget instead, while keeping the interactive ceiling for the
    # public API.
    INTERNAL_MAX_SECONDS = 5.minutes.to_i

    def max_seconds(query)
      query.context[:internal_use] ? INTERNAL_MAX_SECONDS : super
    end

    def handle_timeout(error, query)
      error.extensions = { code: :timeout }

      Sentry.capture_exception(error, extra: {
        procedure_id: query.variables["demarcheNumber"],
        variables: query.variables&.to_h,
        query_string: filter_sensitive_query_string(query.query_string),
        operation_name: query.operation_name,
      })
    end

    private

    def filter_sensitive_query_string(query_string)
      filter_patterns = Rails.application.config.filter_parameters

      query_string_dup = query_string.dup

      filter_patterns.each do |pattern|
        query_string_dup.gsub!(pattern.to_s, "[FILTERED]")
      end

      query_string_dup
    end
  end

  use Timeout, max_seconds: 30
  use GraphQL::Backtrace if Rails.env.development?
  use GraphQL::Schema::Visibility
  use GraphQL::Dataloader

  if Rails.env.development?
    class LogQueryDepth < GraphQL::Analysis::AST::QueryDepth
      def result
        Rails.logger.info("[GraphQL Query Depth] #{super}")
      end
    end

    class LogQueryComplexity < GraphQL::Analysis::AST::QueryComplexity
      def result
        Rails.logger.info("[GraphQL Query Complexity] #{super}")
      end
    end

    query_analyzer(LogQueryComplexity)
    query_analyzer(LogQueryDepth)
  end
end
