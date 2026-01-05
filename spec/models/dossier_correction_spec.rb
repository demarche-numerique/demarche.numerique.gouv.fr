# frozen_string_literal: true

describe DossierCorrection do
  let(:dossier) { create(:dossier, :en_construction) }
  let(:commentaire) { create(:commentaire, dossier: dossier) }
  let(:correction) { create(:dossier_correction, dossier: dossier, commentaire: commentaire) }

  describe '#pending?' do
    context 'when not resolved and not cancelled' do
      it { expect(correction.pending?).to be true }
    end

    context 'when resolved' do
      before { correction.update!(resolved_at: Time.current) }

      it { expect(correction.pending?).to be false }
    end

    context 'when cancelled' do
      before { correction.update!(cancelled_at: Time.current) }

      it { expect(correction.pending?).to be false }
    end
  end

  describe '#cancelled?' do
    context 'when cancelled_at is nil' do
      it { expect(correction.cancelled?).to be false }
    end

    context 'when cancelled_at is present' do
      before { correction.update!(cancelled_at: Time.current) }

      it { expect(correction.cancelled?).to be true }
    end
  end

  describe '#cancel!' do
    it 'sets cancelled_at' do
      expect { correction.cancel! }.to change { correction.cancelled? }.from(false).to(true)
    end

    it 'also resolves the correction' do
      expect { correction.cancel! }.to change { correction.resolved? }.from(false).to(true)
    end

    it 'destroys the attente_correction notification' do
      create(:dossier_notification, dossier: dossier, notification_type: :attente_correction)
      expect { correction.cancel! }.to change { DossierNotification.where(notification_type: :attente_correction).count }.by(-1)
    end
  end

  describe '.pending scope' do
    let!(:pending_correction) { create(:dossier_correction, dossier: dossier) }
    let!(:resolved_correction) { create(:dossier_correction, dossier: dossier, resolved_at: Time.current) }
    let!(:cancelled_correction) { create(:dossier_correction, dossier: dossier, cancelled_at: Time.current) }

    it 'returns only pending corrections' do
      expect(DossierCorrection.pending).to include(pending_correction)
      expect(DossierCorrection.pending).not_to include(resolved_correction)
      expect(DossierCorrection.pending).not_to include(cancelled_correction)
    end
  end
end
