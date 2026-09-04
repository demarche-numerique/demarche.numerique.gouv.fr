# frozen_string_literal: true

class Champs::PreRempliChamp < ChampData
  def selected
    value
  end

  def condition_value = selected.presence
end
