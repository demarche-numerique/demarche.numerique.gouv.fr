# frozen_string_literal: true

# DSFR "translate" dropdown, opened by the DSFR collapse JS.
class Dsfr::TranslateMenuComponent < ApplicationComponent
  renders_one :button

  attr_reader :id, :title, :list_tag, :button_class, :item_class, :menu_class, :list_class

  def initialize(id:, title: nil, list_tag: :ul, button_class: nil, item_class: nil, menu_class: nil, list_class: nil)
    @id = id
    @title = title
    @list_tag = list_tag
    @button_class = button_class
    @item_class = item_class
    @menu_class = menu_class
    @list_class = list_class
  end
end
