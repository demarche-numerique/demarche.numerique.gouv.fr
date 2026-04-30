# frozen_string_literal: true

class Zone < ApplicationRecord
  validates :acronym, presence: true, uniqueness: true
  has_many :labels, -> { order(designated_on: :desc) }, class_name: 'ZoneLabel', inverse_of: :zone
  has_and_belongs_to_many :procedures, -> { order(published_at: :desc) }, inverse_of: :zone

  OTHER_ZONE = 'Autre'

  def current_label
    labels.where.not(name: 'Non attribué').first.name
  end

  def label_at(date)
    labels.where(designated_on: ...date).first&.name || labels.last&.name
  end

  def available_at?(date)
    label_at(date) != 'Non attribué'
  end

  def self.available_at(date, without_zones = [])
    # Charger toutes les zones qui ne sont pas dans without_zones
    zones = Zone.where.not(id: without_zones).order(:acronym).to_a

    # Charger tous les labels pertinents (ceux désignés avant la date donnée) en une seule requête
    labels_by_zone = ZoneLabel
      .where(designated_on: ..date)
      .where(zone_id: zones.map(&:id))
      .order(designated_on: :desc)
      .group_by(&:zone_id)

    # Préparer la liste des zones avec leurs labels
    zones.map do |zone|
      label = labels_by_zone[zone.id]&.first&.name
      next if label.nil? || label == 'Non attribué' # Exclure les zones sans label ou avec "Non attribué"
      LabelModel.new(id: zone.id, label: label)
    end.compact
  end

  def self.default_for(tchap_hs)
    Zone.where("? = ANY (tchap_hs)", tchap_hs)
  end
end
