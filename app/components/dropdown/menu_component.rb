# frozen_string_literal: true

class Dropdown::MenuComponent < ApplicationComponent
  renders_one :button_inner_html
  renders_one :menu_header_html
  # in a menu (no forms, no explicit role), item links/buttons must carry role: 'menuitem'
  renders_many :items, -> (options = {}, &block) do
    tag.li(**options, &block)
  end
  renders_many :forms

  def initialize(wrapper:,
    wrapper_options: {},
    button_options: {},
    menu_options: {},
    role: nil)
    @wrapper = wrapper
    @wrapper_options = wrapper_options
    @button_options = button_options
    @menu_options = menu_options
    @role = role
  end

  def wrapper_options
    @wrapper_options.deep_merge({
      class: wrapper_class_names,
      data: { controller: token_list('menu-button', @wrapper_options.dig(:data, :controller)) },
    })
  end

  def wrapper_class_names
    ['dropdown'] + Array(@wrapper_options[:class])
  end

  def button_id
    "#{menu_id}_button"
  end

  def menu_id
    @menu_options[:id] ||= SecureRandom.uuid
    @menu_options[:id]
  end

  def menu_role
    return @role if @role
    forms? ? :region : :menu
  end

  def menu?
    menu_role.to_s == 'menu'
  end

  def menu_class_names
    ['dropdown-content'] + Array(@menu_options[:class])
  end

  def button_class_names
    ['fr-btn', 'dropdown-button'] + Array(@button_options[:class])
  end

  def disabled?
    @button_options[:disabled] == true
  end

  def title
    @button_options[:title]
  end

  def data
    { menu_button_target: 'button' }.deep_merge(@button_options[:data].to_h)
  end
end
