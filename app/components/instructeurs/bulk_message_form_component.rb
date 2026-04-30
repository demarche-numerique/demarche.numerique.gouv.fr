# frozen_string_literal: true

class Instructeurs::BulkMessageFormComponent < ApplicationComponent
  attr_reader :current_instructeur, :procedure, :dossiers_count_per_groupe_instructeur

  def initialize(current_instructeur:, procedure:, dossiers_count_per_groupe_instructeur:)
    @current_instructeur = current_instructeur
    @procedure = procedure
    @dossiers_count_per_groupe_instructeur = dossiers_count_per_groupe_instructeur
  end

  def default_dossiers_count
    if procedure.routing_enabled
      @dossiers_count_per_groupe_instructeur.sum do |groupe_instructeur_id, dossier_count|
        if instructeur_in_all_groupes? || current_instructeur_in_groupe?(groupe_instructeur_id)
          dossier_count
        else
          0
        end
      end
    else
      @dossiers_count_per_groupe_instructeur.values.sum
    end
  end

  # grouped by groupe_instructeur_id, those without is indexed by nil
  def dossier_count_without_group = @dossiers_count_per_groupe_instructeur[nil]

  def groupe_instructeurs_with_brouillon = procedure.groupe_instructeurs.filter { dossier_count_for(_1)&.> 0 }

  def splitted_groupe_instructeurs = yield(*groupe_instructeurs_with_brouillon.partition { current_instructeur_in_groupe?(_1.id) })

  def groupe_instructeur_checkbox(form, groupe_instructeur)
    form.check_box(
      groupe_instructeur.id,
      {
        checked: current_instructeur_in_groupe?(groupe_instructeur.id),
        data: {
          "checkbox-select-all-target": "checkbox",
          **bulk_message_stimulus_data(dossier_count_for(groupe_instructeur)),
        },
      },
      'true',
      'false'
    )
  end

  def groupe_instructeur_label(form, groupe_instructeur)
    form.label groupe_instructeur.id, class: 'fr-label' do
      safe_join([
        groupe_instructeur.label,
        tooltip_tag(groupe_instructeur),
        tag.span(class: 'fr-hint-text') do
          safe_join([
            t('.dossier_count_per_group', count: dossier_count_for(groupe_instructeur)),
            text_belongs_to_group(groupe_instructeur),
          ])
        end,
      ])
    end
  end

  def bulk_message_stimulus_data(count)
    {
      "bulk-message-target": "element",
      "action": "change->bulk-message#change",
      "count": count,
    }
  end

  def render_select_all? = @select_all ||= groupe_instructeurs_with_brouillon.size >= 6

  def instructeur_in_all_groupes? = @in_all_groupes ||= procedure.groupe_instructeurs.size == instructeur_groupe_ids.size

  def bulk_message
    current_instructeur
      .bulk_messages
      .build.tap do |bulk_message|
        bulk_message.without_group = instructeur_in_all_groupes?
      end
  end

  private

  def dossier_count_for(groupe_instructeur) = @dossiers_count_per_groupe_instructeur[groupe_instructeur.id] || 0

  def current_instructeur_in_groupe?(groupe_instructeur_id) = groupe_instructeur_id.in?(instructeur_groupe_ids)

  def text_belongs_to_group(groupe_instructeur)
    if current_instructeur_in_groupe?(groupe_instructeur.id)
      tag.span(t('.present_in_group'))
    else
      tag.span(t('.not_present_in_group'))
    end
  end

  def tooltip_tag(groupe_instructeur)
    return if groupe_instructeur.routing_rule.blank?

    safe_join([
      tag.span(
        "",
        class: "fr-icon-information-line fr-icon--sm fr-ml-2v",
        id: "link-#{groupe_instructeur.id}",
        aria: { describedby: "tooltip-#{groupe_instructeur.id}" }
      ),
      tag.span(
        groupe_instructeur.routing_rule.to_s(procedure.active_revision.types_de_champ),
        class: 'fr-tooltip fr-placement',
        id: "tooltip-#{groupe_instructeur.id}",
        role: "tooltip",
        aria: { hidden: "true" }
      ),
    ])
  end

  def instructeur_groupe_ids
    @instructeur_groupe_ids ||= current_instructeur
      .groupe_instructeurs
      .filter { _1.procedure_id == procedure.id }
      .map(&:id)
  end
end
