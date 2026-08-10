# frozen_string_literal: true

require 'rails_helper'

describe EditableChamp::PreRempliComponent, type: :component do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :pre_rempli }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.root_public_champs.first }
  let(:form) do
    ActionView::Helpers::FormBuilder.new("dossier[champs_public_attributes]", champ, ActionController::Base.new.view_context, {})
  end
  let(:component) { described_class.new(form:, champ:) }

  subject { render_inline(component) }

  context "when champ has a value" do
    before { champ.update(value: "Valeur pré-remplie") }

    it "renders a disabled text input with the value" do
      expect(subject).to have_field(type: 'text', with: 'Valeur pré-remplie', disabled: true)
    end

    it "renders with fr-input class" do
      expect(subject).to have_css("input.fr-input[disabled]")
    end
  end

  context "when champ has no value" do
    it "renders a disabled text input that is empty" do
      expect(subject).to have_css("input[type='text'][disabled]")
    end
  end
end
