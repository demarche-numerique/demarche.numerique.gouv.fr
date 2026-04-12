# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SelectProcedureDropDownListComponent, type: :component do
  subject do
    render_inline(described_class.new(procedures:, action_path:, form_class:))
  end

  let(:procedure_struct) { Struct.new(:id, :libelle) }
  let(:procedures) do
    [
      procedure_struct.new(1001, "Procedure importante"),
      procedure_struct.new(1002, "Procedure facile"),
      procedure_struct.new(1003, "Procedure terminée"),
      procedure_struct.new(1004, "Procedure terminée 2"),
      procedure_struct.new(1005, "Procedure terminée 3"),
    ]
  end

  let(:action_path) { '/test/path' }
  let(:form_class) { 'ml-auto' }

  let(:react_component) do
    page.find(
      'script.js-react-on-rails-component[data-component-name="SelectProcedureDropDownList"]',
      visible: false
    )
  end
  let(:react_props_items) { JSON.parse(react_component.text(:all)) }

  it 'renders the label' do
    expect(subject).to have_text('Accès direct')
  end

  it 'renders the procedures' do
    subject
    expect(react_props_items["items"]).to eq([
      ["n°1001 - Procedure importante", 1001],
      ["n°1002 - Procedure facile", 1002],
      ["n°1003 - Procedure terminée", 1003],
      ["n°1004 - Procedure terminée 2", 1004],
      ["n°1005 - Procedure terminée 3", 1005],
    ])
  end

  it 'includes the action path in the props' do
    subject
    expect(react_props_items["data"]["action_path"]).to eq('/test/path')
  end

  it 'renders the React on Rails mount point' do
    subject
    expect(page).to have_selector('#select-procedure-drop-down-list-react-component.flex-1')
  end

  it 'applies the form class' do
    subject
    expect(page).to have_selector('form.ml-auto')
  end

  context 'when there are less than 4 procedures' do
    let(:procedures) do
      [
        procedure_struct.new(1, "Procedure 1"),
        procedure_struct.new(2, "Procedure 2"),
        procedure_struct.new(3, "Procedure 3"),
      ]
    end

    it 'does not render' do
      expect(subject.to_html).to be_empty
    end
  end

  context 'when action path is for admin' do
    let(:action_path) { '/admin/procedures/select_procedure' }

    it 'renders with flex-1 class' do
      subject
      expect(page).to have_selector('.flex-1')
    end
  end

  context 'when action path is for instructeur' do
    let(:action_path) { '/instructeur/procedures/select_procedure' }

    it 'renders with flex-1 class' do
      subject
      expect(page).to have_selector('.flex-1')
    end
  end
end
