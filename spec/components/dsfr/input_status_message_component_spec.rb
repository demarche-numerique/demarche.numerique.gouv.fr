# frozen_string_literal: true

describe Dsfr::InputStatusMessageComponent, type: :component do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :piece_justificative, nature: 'rib' }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champ_data.first }

  describe 'announcement mode' do
    context 'when the RIB analysis is pending' do
      before { champ.update_column(:external_state, :waiting_for_job) }

      it 'renders only the status text (no .fr-messages-group wrapper)' do
        render_inline(described_class.new(champ:, as_announcement: true))
        expect(page).to have_text('Contenu du fichier en cours')
        expect(page).not_to have_css('.fr-messages-group')
      end
    end

    context 'when the champ is idle (no status to announce)' do
      it 'renders nothing' do
        render_inline(described_class.new(champ:, as_announcement: true))
        expect(page).not_to have_text('Contenu du fichier')
        expect(page).not_to have_css('.fr-messages-group')
      end
    end
  end

  describe 'visible mode aria-live' do
    let(:no_error_component) { double('champ_component', errors_on_attribute?: false, error_full_messages: [], attribute: :value) }
    let(:error_component) { double('champ_component', errors_on_attribute?: true, error_full_messages: ['est invalide'], attribute: :value) }

    context 'with a status message and no validation error' do
      before { champ.update_column(:external_state, :waiting_for_job) }

      it 'drops aria-live (the sr-only region announces the status instead)' do
        render_inline(described_class.new(champ:, champ_component: no_error_component))
        expect(page).to have_css('.fr-messages-group')
        expect(page).not_to have_css('.fr-messages-group[aria-live]')
      end
    end

    context 'with a validation error' do
      it 'keeps aria-live="assertive" for the error' do
        render_inline(described_class.new(champ:, champ_component: error_component))
        expect(page).to have_css('.fr-messages-group[aria-live="assertive"]')
      end
    end
  end

  describe 'a degraded siret champ' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :siret }]) }

    before do
      champ.update_columns(external_id: '30613890001294', value: '30613890001294', external_state: 'degraded')
    end

    it 'tells the user their SIRET is kept, instead of staying silent' do
      render_inline(described_class.new(champ:, as_announcement: true))

      expect(page).to have_text('306 138 900 01294')
      expect(page).to have_text('vous pouvez continuer')
    end
  end
end
