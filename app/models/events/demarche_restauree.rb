# frozen_string_literal: true

module Events
  # The restore of a removed démarche; the restores of its dossiers follow,
  # with this event as their correlation and causation.
  class DemarcheRestauree < ProcedureEvent
  end
end
