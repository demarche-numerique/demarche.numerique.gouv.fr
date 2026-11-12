# frozen_string_literal: true

require 'rails_helper'

describe EditableChamp::ReferentielComponent, type: :component do
  let(:public_type_de_champs) { [{ type: :referentiel, referentiel:, referentiel_mapping: {} }] }
  let(:procedure) { create(:procedure, public_type_de_champs:) }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:champ) { dossier.public_root_champs.first }
  let(:form) do
    ActionView::Helpers::FormBuilder.new("dossier[champs_public_attributes]", champ, ActionController::Base.new.view_context, {})
  end

  let(:component) { described_class.new(form:, champ:) }
  subject { render_inline(component) }

  context 'when referentiel is nil' do
    let(:referentiel) { nil }

    it 'renders a disabled input without crashing' do
      expect(subject).to have_field(type: 'text', disabled: true)
    end

    it 'does not render the autocomplete combobox' do
      expect(subject).not_to have_selector('react-fragment')
    end
  end

  context 'when referentiel is present' do
    let(:referentiel) { create(:api_referentiel, :autocomplete) }

    it 'renders the autocomplete combobox' do
      expect(subject).to have_selector('react-fragment')
    end

    it 'includes dossier_id but no row_id in loader URL' do
      expect(subject.to_html).to include("dossier_id=#{dossier.id}")
      expect(subject.to_html).not_to include("row_id")
    end

    context 'when the champ is inside a repetition' do
      let(:public_type_de_champs) do
        [{ type: :repetition, stable_id: 100, children: [{ type: :referentiel, stable_id: 101, referentiel:, referentiel_mapping: {} }] }]
      end
      let(:dossier) { create(:dossier, procedure:) }
      let(:row_id) { dossier.repetition_add_row(dossier.find_type_de_champ_by_stable_id(100), updated_by: 'test') }
      let(:champ) do
        dossier.champ_for_update(dossier.find_type_de_champ_by_stable_id(101), row_id:, updated_by: 'test')
      end

      it 'includes the row_id in loader URL, so the API call resolves the champs of this row' do
        expect(subject.to_html).to include("row_id=#{row_id}")
      end
    end
  end

  context 'when an annotation prefills the form of a dossier that cannot go back to the usager' do
    let(:procedure) do
      create(:procedure,
             public_type_de_champs: [{ type: :text, libelle: 'Nom', stable_id: 99 }],
             private_type_de_champs: [{ type: :referentiel, stable_id: 88, referentiel:, referentiel_mapping: { "$.nom" => { prefill: "1", prefill_stable_id: 99, type: "string" } } }])
    end
    let(:dossier) { create(:dossier, :accepte, procedure:) }
    let(:champ) { dossier.champ_data.find { it.stable_id == 88 } }
    let(:form) do
      ActionView::Helpers::FormBuilder.new("dossier[champs_private_attributes]", champ, ActionController::Base.new.view_context, {})
    end

    context 'in exact match mode' do
      let(:referentiel) { create(:api_referentiel, :exact_match) }

      it 'disables the field and says why' do
        expect(subject).to have_field(type: 'text', disabled: true)
        expect(subject).to have_text('ce champ, qui préremplit son formulaire, n’est plus modifiable')
        expect(subject).to have_selector("input[aria-describedby~='#{champ.html_id}-locked']")
      end
    end

    context 'in autocomplete mode' do
      let(:referentiel) { create(:api_referentiel, :autocomplete) }

      it 'disables the combobox and says why' do
        expect(subject.to_html).to include('&quot;is_disabled&quot;:true')
        expect(subject).to have_text('ce champ, qui préremplit son formulaire, n’est plus modifiable')
      end
    end
  end
end
