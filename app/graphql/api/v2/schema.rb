# frozen_string_literal: true

class API::V2::Schema < GraphQL::Schema
  default_max_page_size 100
  default_page_size 100
  # Disable max_complexity for now because of what looks like a bug in graphql gem.
  # After some internal changes complexity for our avarage query went from < 300 to 25 000.
  max_complexity nil
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
    Types::PersonneMoraleType,
    Types::PersonneMoraleIncompleteType,
    Types::PersonnePhysiqueType,
    Types::Champs::Descriptor::AddressChampDescriptorType,
    Types::Champs::Descriptor::AnnuaireEducationChampDescriptorType,
    Types::Champs::Descriptor::CarteChampDescriptorType,
    Types::Champs::Descriptor::CheckboxChampDescriptorType,
    Types::Champs::Descriptor::CiviliteChampDescriptorType,
    Types::Champs::Descriptor::CnafChampDescriptorType,
    Types::Champs::Descriptor::COJOChampDescriptorType,
    Types::Champs::Descriptor::CommuneChampDescriptorType,
    Types::Champs::Descriptor::DateChampDescriptorType,
    Types::Champs::Descriptor::DatetimeChampDescriptorType,
    Types::Champs::Descriptor::DecimalNumberChampDescriptorType,
    Types::Champs::Descriptor::DepartementChampDescriptorType,
    Types::Champs::Descriptor::DgfipChampDescriptorType,
    Types::Champs::Descriptor::DossierLinkChampDescriptorType,
    Types::Champs::Descriptor::DropDownListChampDescriptorType,
    Types::Champs::Descriptor::EmailChampDescriptorType,
    Types::Champs::Descriptor::EpciChampDescriptorType,
    Types::Champs::Descriptor::ExplicationChampDescriptorType,
    Types::Champs::Descriptor::HeaderSectionChampDescriptorType,
    Types::Champs::Descriptor::IbanChampDescriptorType,
    Types::Champs::Descriptor::IntegerNumberChampDescriptorType,
    Types::Champs::Descriptor::LinkedDropDownListChampDescriptorType,
    Types::Champs::Descriptor::MesriChampDescriptorType,
    Types::Champs::Descriptor::MultipleDropDownListChampDescriptorType,
    Types::Champs::Descriptor::NumberChampDescriptorType,
    Types::Champs::Descriptor::PaysChampDescriptorType,
    Types::Champs::Descriptor::PhoneChampDescriptorType,
    Types::Champs::Descriptor::PieceJustificativeChampDescriptorType,
    Types::Champs::Descriptor::PoleEmploiChampDescriptorType,
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
    Types::Columns::AttachmentsColumnType,
    Types::Columns::BooleanColumnType,
    Types::Columns::DateColumnType,
    Types::Columns::DateTimeColumnType,
    Types::Columns::DecimalColumnType,
    Types::Columns::EnumColumnType,
    Types::Columns::EnumsColumnType,
    Types::Columns::IntegerColumnType,
    Types::Columns::TextColumnType

  def self.unauthorized_object(error)
    # Add a top-level error to the response instead of returning nil:
    raise GraphQL::ExecutionError.new("An object of type #{error.type.graphql_name} was hidden due to permissions", extensions: { code: :unauthorized })
  end

  def self.type_error(error, ctx)
    # Capture type errors in Sentry. Thouse errors are our responsability and usually linked to
    # instances of "bad data".
    Sentry.capture_exception(error, extra: ctx.query_info)

    if error.is_a?(GraphQL::InvalidNullError)
      execution_error = GraphQL::ExecutionError.new(error.message, ast_node: error.ast_node, extensions: { code: :invalid_null })
      execution_error.path = ctx[:current_path]
      ctx.errors << execution_error
    else
      super
    end
  end

  rescue_from(ActiveRecord::RecordNotFound) do |_error, _object, _args, _ctx, field|
    raise GraphQL::ExecutionError.new("#{field.type.unwrap.graphql_name} not found", extensions: { code: :not_found })
  end

  class Timeout < GraphQL::Schema::Timeout
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
  use GraphQL::Batch
  use GraphQL::Backtrace
  use GraphQL::Schema::Visibility

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
