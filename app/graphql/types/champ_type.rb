# frozen_string_literal: true

module Types
  module ChampType
    include Types::BaseInterface

    global_id_field :id
    field :champ_descriptor_id, String, "L’identifiant du champDescriptor de ce champ", null: false
    field :label, String, "Libellé du champ.", null: false, method: :libelle
    field :string_value, String, "La valeur du champ sous forme texte.", null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, "Date de dernière modification du champ.", null: false
    field :prefilled, Boolean, null: false, method: :prefilled?
    field :columns, [Types::ColumnType], "Les colonnes sont des données associées à un champ. ex: Pour un champ adresse, nous pouvons renvoyer les composant (rue, code postal, departement, region) sous formes de colonne", null: false

    def string_value
      object.type_de_champ.champ_value_for_api(object)
    end

    def columns
      if object.repetition? || object.titre_identite?
        []
      else
        object.type_de_champ.columns(procedure: object.procedure)
      end
    end

    definition_methods do
      def resolve_type(object, context)
        case object
        when ::Champs::AddressChamp
          if context.has_fragment?(:AddressChamp)
            Types::Champs::AddressChampType
          else
            Types::Champs::TextChampType
          end
        when ::Champs::CheckboxChamp
          Types::Champs::CheckboxChampType
        when ::Champs::YesNoChamp
          if context.has_fragment?(:YesNoChamp)
            Types::Champs::YesNoChampType
          else
            Types::Champs::CheckboxChampType
          end
        when ::Champs::DateChamp
          Types::Champs::DateChampType
        when ::Champs::DatetimeChamp
          if context.has_fragment?(:DatetimeChamp)
            Types::Champs::DatetimeChampType
          else
            Types::Champs::DateChampType
          end
        when ::Champs::CommuneChamp
          if context.has_fragment?(:CommuneChamp)
            Types::Champs::CommuneChampType
          else
            Types::Champs::TextChampType
          end
        when ::Champs::DepartementChamp
          if context.has_fragment?(:DepartementChamp)
            Types::Champs::DepartementChampType
          else
            Types::Champs::TextChampType
          end
        when ::Champs::RegionChamp
          if context.has_fragment?(:RegionChamp)
            Types::Champs::RegionChampType
          else
            Types::Champs::TextChampType
          end
        when ::Champs::PaysChamp
          if context.has_fragment?(:PaysChamp)
            Types::Champs::PaysChampType
          else
            Types::Champs::TextChampType
          end
        when ::Champs::DossierLinkChamp
          Types::Champs::DossierLinkChampType
        when ::Champs::PieceJustificativeChamp
          Types::Champs::PieceJustificativeChampType
        when ::Champs::CarteChamp
          Types::Champs::CarteChampType
        when ::Champs::NumberChamp, ::Champs::IntegerNumberChamp
          Types::Champs::IntegerNumberChampType
        when ::Champs::DecimalNumberChamp
          Types::Champs::DecimalNumberChampType
        when ::Champs::SiretChamp
          Types::Champs::SiretChampType
        when ::Champs::RepetitionChamp
          Types::Champs::RepetitionChampType
        when ::Champs::MultipleDropDownListChamp
          Types::Champs::MultipleDropDownListChampType
        when ::Champs::LinkedDropDownListChamp
          Types::Champs::LinkedDropDownListChampType
        when ::Champs::CiviliteChamp
          Types::Champs::CiviliteChampType
        when ::Champs::TitreIdentiteChamp
          Types::Champs::TitreIdentiteChampType
        when ::Champs::EpciChamp
          Types::Champs::EpciChampType
        when ::Champs::RNAChamp
          Types::Champs::RNAChampType
        when ::Champs::RNFChamp
          Types::Champs::RNFChampType
        when ::Champs::EngagementJuridiqueChamp
          Types::Champs::EngagementJuridiqueChampType
        when ::Champs::HeaderSectionChamp
          if context.has_fragment?(:HeaderSectionChamp)
            Types::Champs::HeaderSectionChampType
          else
            Types::Champs::TextChampType
          end
        when ::Champs::ExplicationChamp
          if context.has_fragment?(:ExplicationChamp)
            Types::Champs::ExplicationChampType
          else
            Types::Champs::TextChampType
          end
        when ::Champs::DropDownListChamp
          if context.has_fragment?(:DropDownListChamp)
            Types::Champs::DropDownListChampType
          else
            Types::Champs::TextChampType
          end
        else
          Types::Champs::TextChampType
        end
      end
    end
  end
end
