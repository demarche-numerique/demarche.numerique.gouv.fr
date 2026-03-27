# frozen_string_literal: true

module TypeDeChampSelectorHelpers
  def select_type_de_champ(value, from_selector: nil)
    container = from_selector || find('.type-de-champ-selector', match: :first)
    trigger = container.find('[data-type-de-champ-selector-target="trigger"]')
    trigger.click
    container.find("[data-type-de-champ-selector-target='panel']:not(.fr-hidden)")
    container.find("[data-value='#{value}']").click
  end
end

RSpec.configure do |config|
  config.include TypeDeChampSelectorHelpers, type: :system
end
