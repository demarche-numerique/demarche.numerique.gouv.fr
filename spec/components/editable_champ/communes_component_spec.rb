# frozen_string_literal: true

describe EditableChamp::CommunesComponent, type: :component do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :communes }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:tdc) { procedure.active_revision.types_de_champ.first }
  let(:champ) { dossier.champs.first }

  describe 'aria-describedby' do
    let(:react_component) { page.first('react-component') }
    let(:react_props) { JSON.parse(react_component['props']) }

    subject do
      component = nil
      ActionView::Base.empty.form_for(champ, url: '/') do |form|
        component = EditableChamp::EditableChampComponent.new(champ:, form:)
      end

      render_inline(component)
      react_props['aria-describedby']&.split
    end

    context 'when the champ has a description' do
      it { is_expected.to eq([champ.describedby_id]) }

      context 'and the champ has an error' do
        before { champ.dossier.errors.import(champ.errors.add(:value, 'error')) }

        it { is_expected.to eq([champ.describedby_id, champ.error_id(:value)]) }
      end
    end

    context 'when the champ has no description' do
      before { tdc.update(description: nil) }

      it { is_expected.to be_nil }

      context 'and the champ has an error' do
        before { dossier.errors.import(champ.errors.add(:value, 'error')) }

        it { is_expected.to eq([champ.error_id(:value)]) }
      end
    end
  end

  describe 'not_in_api_geo fallback' do
    subject do
      component = nil
      ActionView::Base.empty.form_for(champ, url: '/') do |form|
        component = EditableChamp::EditableChampComponent.new(champ:, form:)
      end

      render_inline(component)
    end

    context 'when not_in_api_geo is false' do
      before { champ.update_column(:value_json, {}) }

      it 'renders the checkbox unchecked and text input hidden' do
        subject
        checkbox = page.first("input[type='checkbox'][name*='not_in_api_geo']", visible: :all)
        expect(checkbox).not_to be_checked
        expect(page).to have_css(".fr-fieldset__element.hidden input[name*='value']", visible: :all)
      end
    end

    context 'when not_in_api_geo is true' do
      before { champ.update_column(:value_json, { not_in_api_geo: 'true' }) }

      it 'renders the checkbox checked and a text input' do
        subject
        checkbox = page.first("input[type='checkbox'][name*='not_in_api_geo']", visible: :all)
        expect(checkbox).to be_checked
        expect(page).to have_css("input[name*='value']")
      end
    end
  end
end
