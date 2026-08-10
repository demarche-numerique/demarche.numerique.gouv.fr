# frozen_string_literal: true

class ViewableChamp::HeaderSectionsSummaryComponent < ApplicationComponent
  Entry = Data.define(:libelle, :anchor_id, :level)

  def initialize(dossier:, is_private:)
    @dossier = dossier
    @is_private = is_private
  end

  # Visible header sections, repetitions and their rows in document order.
  # Sections hidden by a condition are excluded.
  def sections
    @sections ||= flatten_sections(root_champs, 1)
  end

  def render? = sections.any?

  private

  def root_champs
    @is_private ? @dossier.private_champs : @dossier.public_champs
  end

  def flatten_sections(champs, depth)
    champs.filter { (it.header_section? || it.repetition?) && it.visible? }.flat_map do |champ|
      children = if champ.header_section?
        flatten_sections(champ.children, depth + 1)
      else
        row_entries(champ, depth + 1)
      end
      [Entry.new(libelle: champ.libelle, anchor_id: champ.html_id, level: depth), *children]
    end
  end

  # Each row of a repetition is listed with its own sections beneath it.
  def row_entries(champ, depth)
    champ.rows.flat_map do |row|
      [
        Entry.new(libelle: "#{champ.libelle} #{row.index}", anchor_id: row.html_id, level: depth),
        *flatten_sections(row.champs, depth + 1),
      ]
    end
  end
end
