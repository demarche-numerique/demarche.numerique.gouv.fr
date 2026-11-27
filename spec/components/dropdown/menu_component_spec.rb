# frozen_string_literal: true

RSpec.describe Dropdown::MenuComponent, type: :component do
  subject do
    render_inline(described_class.new(wrapper: :div, menu_options: { id: 'my-menu' }, role:)) do |menu|
      menu.with_button_inner_html { 'Actions' }
      if with_form
        menu.with_form { '<form></form>'.html_safe }
      else
        menu.with_item { '<a href="#" role="menuitem">Item</a>'.html_safe }
      end
    end
  end

  let(:role) { nil }
  let(:with_form) { false }

  context 'with menu items' do
    it 'follows the menu button pattern' do
      expect(subject).to have_selector('button[aria-haspopup="menu"][aria-expanded="false"][aria-controls="my-menu"]')
      expect(subject).to have_selector('#my-menu[role="menu"] ul[role="none"] > li[role="none"] > [role="menuitem"]')
    end
  end

  context 'with a form' do
    let(:with_form) { true }

    it 'follows the disclosure pattern' do
      expect(subject).to have_selector('button[aria-expanded="false"][aria-controls="my-menu"]:not([aria-haspopup])')
      expect(subject).to have_selector('#my-menu[role="region"]')
    end
  end

  context 'with an explicit region role' do
    let(:role) { :region }

    it 'follows the disclosure pattern and keeps the list semantics' do
      expect(subject).to have_selector('button[aria-expanded="false"]:not([aria-haspopup])')
      expect(subject).to have_selector('ul.dropdown-items:not([role]) > li:not([role])')
    end
  end
end
