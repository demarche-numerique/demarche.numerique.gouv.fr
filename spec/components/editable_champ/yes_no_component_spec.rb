# frozen_string_literal: true

describe EditableChamp::YesNoComponent, type: :component do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :yes_no }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:tdc) { procedure.active_revision.types_de_champ.first }
  let(:champ) { dossier.champ_data.first }

  subject(:render) do
    component = nil
    ActionView::Base.empty.form_for(champ, url: '/') do |form|
      component = EditableChamp::YesNoComponent.new(champ:, form:)
    end

    render_inline(component)
  end

  let(:radios) { page.all('input[type="radio"]') }

  describe 'not filled option visibility' do
    context 'when the champ is not mandatory' do
      before { tdc.record.update!(mandatory: false) }

      it 'shows the not filled option' do
        render

        expect(radios.map(&:value)).to contain_exactly('', 'true', 'false')
      end
    end

    context 'when the champ is mandatory' do
      before { tdc.record.update!(mandatory: true) }

      it 'does not show the not filled option' do
        render

        expect(radios.map(&:value)).to contain_exactly('true', 'false')
      end
    end
  end
end
