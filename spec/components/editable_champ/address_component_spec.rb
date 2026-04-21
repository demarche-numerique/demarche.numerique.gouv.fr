# frozen_string_literal: true

describe EditableChamp::AddressComponent, type: :component do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :address }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first }

  describe 'commune_not_in_api_geo fallback' do
    subject do
      component = nil
      ActionView::Base.empty.form_for(champ, url: '/') do |form|
        component = EditableChamp::EditableChampComponent.new(champ:, form:)
      end

      render_inline(component)
    end

    context 'when not_in_ban is true and france (commune section visible)' do
      before { champ.update_column(:value_json, { 'not_in_ban' => 'true', 'country_code' => 'FR' }) }

      context 'when commune_not_in_api_geo is false' do
        it 'renders the commune combobox and the checkbox unchecked' do
          subject
          expect(page).to have_css("input[type='checkbox'][name*='commune_not_in_api_geo']", visible: :all)
          checkbox = page.first("input[type='checkbox'][name*='commune_not_in_api_geo']", visible: :all)
          expect(checkbox).not_to be_checked
          expect(page).to have_css('react-component')
        end
      end

      context 'when commune_not_in_api_geo is true' do
        before { champ.update_column(:value_json, { 'not_in_ban' => 'true', 'country_code' => 'FR', 'commune_not_in_api_geo' => 'true' }) }

        it 'renders a text input for city_name instead of the combobox' do
          subject
          checkbox = page.first("input[type='checkbox'][name*='commune_not_in_api_geo']", visible: :all)
          expect(checkbox).to be_checked
          expect(page).to have_css("input[name*='city_name']")
        end
      end
    end
  end
end
