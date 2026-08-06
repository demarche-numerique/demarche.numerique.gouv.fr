# frozen_string_literal: true

class DossierSerializer < ActiveModel::Serializer
  include DossierHelper

  attributes :id,
    :created_at,
    :updated_at,
    :archived,
    :email,
    :state,
    :simplified_state,
    :initiated_at,
    :received_at,
    :processed_at,
    :motivation,
    :instructeurs

  attribute :attestation, if: :include_attestation?
  attribute :justificatif_motivation, if: :include_justificatif_motivation?

  has_one :individual
  has_one :entreprise
  has_one :etablissement
  has_many :cerfa
  has_many :commentaires
  has_many :private_champs, serializer: ChampSerializer
  has_many :pieces_justificatives
  has_many :types_de_piece_justificative
  has_many :avis

  has_many :champs, serializer: ChampSerializer

  def champs
    champs = object.root_champs_public.reject { |c| c.type_de_champ.old_pj.present? }

    if object.expose_legacy_carto_api?
      champ_carte = champs.find do |champ|
        champ.type_de_champ.type_champ == TypeDeChamp.type_champs.fetch(:carte)
      end

      if champ_carte.present?
        champs_geo_areas = champ_carte.geo_areas.filter do |geo_area|
          geo_area.source != GeoArea.sources.fetch(:selection_utilisateur)
        end
        champs_geo_areas << champ_carte.selection_utilisateur_legacy_geo_area

        champs += champs_geo_areas.compact
      end
    end

    champs
  end

  def private_champs
    object.root_champs_private
  end

  def cerfa
    []
  end

  def pieces_justificatives
    object.root_champs_public.filter { |champ| champ.type_de_champ.old_pj }.map do |champ|
      {
        created_at: champ.created_at&.in_time_zone('UTC'),
        type_de_piece_justificative_id: champ.type_de_champ.old_pj[:stable_id],
        content_url: champ.type_de_champ.champ_value_for_api(champ, version: 1),
        user: champ.dossier.user,
      }
    end.flatten
  end

  def attestation
    object.attestation&.pdf_url
  end

  def justificatif_motivation
    Rails.application.routes.url_helpers.url_for(object.justificatif_motivation)
  end

  def types_de_piece_justificative
    PiecesJustificativesService.serialize_types_de_champ_as_type_pj(object.revision)
  end

  def email
    object.user&.email
  end

  def entreprise
    object.etablissement&.entreprise
  end

  def state
    dossier_legacy_state(object)
  end

  def simplified_state
    dossier_display_state(object)
  end

  def initiated_at
    object.depose_at&.in_time_zone('UTC')
  end

  def received_at
    object.en_instruction_at&.in_time_zone('UTC')
  end

  def instructeurs
    object.followers_instructeurs.map(&:email)
  end

  def created_at
    object.created_at&.in_time_zone('UTC')
  end

  def updated_at
    object.updated_at&.in_time_zone('UTC')
  end

  def processed_at
    object.processed_at&.in_time_zone('UTC')
  end

  def include_attestation?
    object.accepte?
  end

  def include_justificatif_motivation?
    object.justificatif_motivation.attached?
  end
end
