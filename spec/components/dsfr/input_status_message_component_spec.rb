# frozen_string_literal: true

describe Dsfr::InputStatusMessageComponent, type: :component do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative, nature: 'rib' }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first }

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
end
