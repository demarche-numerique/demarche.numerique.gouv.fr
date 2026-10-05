# frozen_string_literal: true

class EditableChamp::ProposedPrefillComponent < ApplicationComponent
  include Dossiers::ChangedColumnFormatting

  def initialize(champ:)
    @champ = champ
  end

  def render?
    @champ.referentiel? && @champ.proposes_public_changes?
  end

  def source
    @champ.referentiel.try(:domain)
  end

  def title
    source.present? ? t('.title_from_api', source:) : t('.title')
  end

  # [intitulé, [[libellé, valeur]]] : d'abord les champs hors bloc répétable, sans intitulé,
  # puis une entrée par ligne ajoutée.
  def groups
    root_columns, row_columns = changed_columns.partition { it.row_id.nil? }
    root_group = root_columns.empty? ? [] : [[nil, root_columns.map { [it.label, change(it)] }]]

    root_group + added_rows(row_columns)
  end

  def submit_path
    proposition_instructeur_dossier_path(@champ.dossier.procedure, @champ.dossier)
  end

  private

  def changed_columns
    @changed_columns ||= @champ.dossier.instructeur_changed_columns
  end

  def change(column)
    return t('.cleared') if column.value.nil?

    value = format_value(column, column.value)
    return value if column.previous_value.blank?

    safe_join([value, tag.span(t('.replaces', previous_value: format_value(column, column.previous_value)), class: 'fr-text--sm')], ' ')
  end

  # Une annotation n'est jamais dans un bloc répétable public : chaque ligne qu'elle
  # préremplit y est nouvelle, numérotée à la suite des lignes de l'usager.
  def added_rows(row_columns)
    row_columns.group_by(&:row_id).values
      .group_by { repetition(it.first) }
      .flat_map do |repetition, rows|
        first_number = @champ.dossier.repetition_row_ids(repetition).size + 1
        rows.map.with_index(first_number) do |columns, number|
          [t('.row_added', libelle: repetition.libelle, number:), columns.map { [libelle(it), change(it)] }]
        end
      end
  end

  def libelle(column) = type_de_champ(column).libelle

  def repetition(column) = @champ.dossier.revision.parent_of(type_de_champ(column))

  def type_de_champ(column) = @champ.dossier.find_type_de_champ_by_stable_id(column.stable_id, :public)
end
