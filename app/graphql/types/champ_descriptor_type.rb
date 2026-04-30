# frozen_string_literal: true

module Types
  module ChampDescriptorType
    include Types::BaseInterface

    class TypeDeChampType < Types::BaseEnum
      TypeDeChamp.type_champs.each do |symbol_name, string_name|
        value(string_name,
          I18n.t(symbol_name, scope: [:activerecord, :attributes, :type_de_champ, :type_champs]),
          value: symbol_name)
      end
    end

    global_id_field :id
    field :label, String, "Libellé du champ.", null: false, method: :libelle
    field :description, String, "Description du champ.", null: true
    field :required, Boolean, "Est-ce que le champ est obligatoire ?", null: false, method: :mandatory?

    field :champ_descriptors, [Types::ChampDescriptorType], "Description des champs d’un bloc répétable.", null: true, deprecation_reason: 'Utilisez le champ `RepetitionChampDescriptor.champ_descriptors` à la place.'
    field :type, TypeDeChampType, "Type de la valeur du champ.", null: false, method: :type_champ, deprecation_reason: 'Utilisez le champ `__typename` à la place.'

    definition_methods do
      def resolve_type(object, context)
        case object.type_champ
        when TypeDeChamp.type_champs.fetch(:referentiel)
          Types::Champs::Descriptor::ReferentielChampDescriptorType

        when TypeDeChamp.type_champs.fetch(:engagement_juridique)
          Types::Champs::Descriptor::EngagementJuridiqueChampDescriptorType

        when TypeDeChamp.type_champs.fetch(:text)
          Types::Champs::Descriptor::TextChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:textarea)
          Types::Champs::Descriptor::TextareaChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:date)
          Types::Champs::Descriptor::DateChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:datetime)
          Types::Champs::Descriptor::DatetimeChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:number)
          Types::Champs::Descriptor::NumberChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:decimal_number)
          Types::Champs::Descriptor::DecimalNumberChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:integer_number)
          Types::Champs::Descriptor::IntegerNumberChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:checkbox)
          Types::Champs::Descriptor::CheckboxChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:civilite)
          Types::Champs::Descriptor::CiviliteChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:email)
          Types::Champs::Descriptor::EmailChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:phone)
          Types::Champs::Descriptor::PhoneChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:address)
          Types::Champs::Descriptor::AddressChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:yes_no)
          Types::Champs::Descriptor::YesNoChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:drop_down_list)
          Types::Champs::Descriptor::DropDownListChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:multiple_drop_down_list)
          Types::Champs::Descriptor::MultipleDropDownListChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:linked_drop_down_list)
          Types::Champs::Descriptor::LinkedDropDownListChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:communes)
          Types::Champs::Descriptor::CommuneChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:departements)
          Types::Champs::Descriptor::DepartementChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:regions)
          Types::Champs::Descriptor::RegionChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:pays)
          Types::Champs::Descriptor::PaysChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:header_section)
          Types::Champs::Descriptor::HeaderSectionChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:explication)
          Types::Champs::Descriptor::ExplicationChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:dossier_link)
          Types::Champs::Descriptor::DossierLinkChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:piece_justificative)
          Types::Champs::Descriptor::PieceJustificativeChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:rna)
          Types::Champs::Descriptor::RNAChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:rnf)
          Types::Champs::Descriptor::RNFChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:carte)
          Types::Champs::Descriptor::CarteChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:repetition)
          Types::Champs::Descriptor::RepetitionChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:iban)
          Types::Champs::Descriptor::IbanChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:siret)
          Types::Champs::Descriptor::SiretChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:annuaire_education)
          Types::Champs::Descriptor::AnnuaireEducationChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:cnaf)
          Types::Champs::Descriptor::CnafChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:dgfip)
          Types::Champs::Descriptor::DgfipChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:pole_emploi)
          Types::Champs::Descriptor::PoleEmploiChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:mesri)
          Types::Champs::Descriptor::MesriChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:epci)
          Types::Champs::Descriptor::EpciChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:cojo)
          Types::Champs::Descriptor::COJOChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:formatted)
          Types::Champs::Descriptor::FormattedChampDescriptorType
        when TypeDeChamp.type_champs.fetch(:quotient_familial)
          Types::Champs::Descriptor::QuotientFamilialChampDescriptorType
        end
      end
    end

    def champ_descriptors
      if type_de_champ.repetition?
        object.revision_types_de_champ
      end
    end

    def type_de_champ
      object.type_de_champ
    end
  end
end
