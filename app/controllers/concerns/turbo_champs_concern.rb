# frozen_string_literal: true

module TurboChampsConcern
  extend ActiveSupport::Concern

  private

  def champs_to_turbo_update(params, champs)
    to_update = champs.filter { it.id.in?(params.keys) }
      .filter { it.refresh_after_update? || it.buffer_stream? }
      .flat_map { [it].concat(it.prefillable_champs) }
    to_show, to_hide = champs_to_toggle(champs, to_update)

    return to_show, to_hide, to_update
  end

  def champ_to_turbo_update(champ, champs)
    to_update = [champ].concat(champ.prefillable_champs)
    to_show, to_hide = champs_to_toggle(champs, to_update)

    return to_show, to_hide, to_update
  end

  def champs_to_toggle(champs, to_update)
    champs.filter { it.conditional? || it.child? }
      .partition(&:visible?)
      .map { champs_to_one_selector(it - to_update) }
  end

  def champs_to_one_selector(champs)
    champs
      .map { "##{it.input_group_id}" }
      .join(',')
  end
end
