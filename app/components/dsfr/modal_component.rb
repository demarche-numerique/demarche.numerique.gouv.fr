# frozen_string_literal: true

# see: https://www.systeme-de-design.gouv.fr/elements-d-interface/composants/modale
# The title gets the id "#{id}-title", which the dialog's aria-labelledby points to.
# A modal whose title arrives later (turbo frame) leaves the title slot empty and
# renders an h1.fr-modal__title with id ModalComponent.title_id(id) itself.
# Extra keyword arguments are deep-merged into the dialog's attributes.
class Dsfr::ModalComponent < ApplicationComponent
  SIZES = {
    sm: 'fr-col-md-6 fr-col-lg-4',
    md: 'fr-col-md-8 fr-col-lg-6',
    lg: 'fr-col-md-10 fr-col-lg-8',
  }.freeze

  DEFAULT_ICON = 'fr-icon-arrow-right-line'

  renders_one :title
  renders_one :footer

  def self.title_id(id) = "#{id}-title"

  def initialize(id:, size: :md, icon: DEFAULT_ICON, title_hidden: false, **html_attributes)
    raise ArgumentError, "unknown modal size: #{size}" unless SIZES.key?(size)

    @id = id
    @size = size
    @icon = icon
    @title_hidden = title_hidden
    @html_attributes = html_attributes
  end

  private

  attr_reader :id, :icon

  def title_id = self.class.title_id(id)

  def column_class = class_names('fr-col-12', SIZES.fetch(@size))

  def title_class = class_names('fr-modal__title', 'fr-sr-only' => @title_hidden)

  def dialog_attributes
    { role: 'dialog' }
      .deep_merge(@html_attributes)
      .deep_merge(id:, aria: { labelledby: title_id })
      .merge(class: class_names('fr-modal', @html_attributes[:class]))
  end
end
