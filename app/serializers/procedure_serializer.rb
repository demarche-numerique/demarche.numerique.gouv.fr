# frozen_string_literal: true

class ProcedureSerializer < ActiveModel::Serializer
  include Rails.application.routes.url_helpers

  attribute :libelle, key: :label

  attributes :id,
    :description,
    :organisation,
    :archived_at,
    :geographic_information,
    :total_dossier,
    :link,
    :state,
    :direction

  has_one :geographic_information, serializer: ModuleAPICartoSerializer
  has_many :types_de_champ, serializer: TypeDeChampSerializer
  has_many :private_types_de_champ, serializer: TypeDeChampSerializer
  has_many :types_de_piece_justificative
  belongs_to :service, serializer: ServiceSerializer

  def direction
    ""
  end

  def archived_at
    object.closed_at&.in_time_zone('UTC')
  end

  def link
    commencer_url(path: object.path)
  end

  def state
    object.aasm_state
  end

  def geographic_information
    if object.expose_legacy_carto_api?
      object.module_api_carto
    else
      ModuleAPICarto.new(procedure: object)
    end
  end

  def types_de_champ
    object.active_revision.root_public_types_de_champ.reject { |c| c.old_pj.present? }
  end

  def private_types_de_champ
    object.active_revision.root_private_types_de_champ
  end

  def types_de_piece_justificative
    PiecesJustificativesService.serialize_types_de_champ_as_type_pj(object.active_revision)
  end
end
