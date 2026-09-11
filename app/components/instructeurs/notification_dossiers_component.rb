# frozen_string_literal: true

# Lists the dossiers carrying a given notification on the instructeur
# procedures page.
#
# Only the dossiers fitting on one desktop line are rendered, the rest is
# summed up by a "(+ N)" indicator. The cut is computed from the text length
# against a fixed width budget, so every instructeur sees the same dossiers
# whatever their screen size; on narrow screens the list simply wraps.
class Instructeurs::NotificationDossiersComponent < ApplicationComponent
  # Width of the list on desktop: the notifications container (1168px)
  # minus the badge column (a quarter of it).
  LINE_WIDTH = 1168 - 1168 / 4
  # Rough width of a Marianne glyph at 14px.
  CHARACTER_WIDTH = 8
  # The vertical bar between two dossiers, with its 1rem margins.
  SEPARATOR_WIDTH = 33
  # Room kept for the "… (+ N)" indicator when the list is cut.
  INDICATOR_WIDTH = 80

  attr_reader :statut, :procedure_id

  def initialize(dossiers:, statut:, procedure_id:)
    @dossiers = dossiers
    @statut = statut
    @procedure_id = procedure_id
  end

  def visible_dossiers
    @dossiers.first(visible_count)
  end

  def hidden_count
    @dossiers.size - visible_count
  end

  def truncated?
    hidden_count > 0
  end

  def linked?
    statut != 'supprimes'
  end

  private

  def visible_count
    @visible_count ||= begin
      count = fitting_count(LINE_WIDTH)

      if count == @dossiers.size
        count
      else
        # Always show at least one dossier, even if it does not fit on the line.
        [fitting_count(LINE_WIDTH - INDICATOR_WIDTH), 1].max
      end
    end
  end

  def fitting_count(budget)
    used = 0

    dossier_widths.take_while.with_index do |width, index|
      used += width
      used += SEPARATOR_WIDTH if index > 0
      used <= budget
    end.size
  end

  def dossier_widths
    @dossier_widths ||= @dossiers.map { "#{it.id} #{it.owner_name}".length * CHARACTER_WIDTH }
  end
end
