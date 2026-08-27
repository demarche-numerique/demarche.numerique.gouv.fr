# frozen_string_literal: true

RSpec.describe ExpertMailer, type: :mailer do
  describe '.send_dossier_decision' do
    let(:mail) { described_class.send_dossier_decision(avis.answered).deliver_now }

    it 'is addressed to the expert who gave the avis' do
      expect(mail.to).to eq([experts.default.email])
    end

    it 'announces the decision in the subject' do
      decision = I18n.t('users.dossiers.attestation_depot.states.accepte')

      expect(mail.subject).to eq("Dossier n° #{dossiers.accepte.id} a été #{decision} - #{procedures.individual.libelle}")
    end

    it 'renders the send_dossier_decision template' do
      body = mail.html_part.body.to_s

      expect(body).to include(dossiers.accepte.id.to_s)
      expect(body).to include(I18n.t('users.dossiers.attestation_depot.states.accepte'))
    end
  end

  # The guard is in the mailer, so it holds whatever the caller did — including
  # a revocation landing between the enqueue and the delivery.
  describe '.send_dossier_decision, once the expert has been revoked' do
    subject { described_class.send_dossier_decision(avis.answered).deliver_now }

    it 'sends nothing when the avis itself is revoked' do
      avis.answered.update!(revoked_at: Time.zone.now)

      expect { subject }.not_to change { ActionMailer::Base.deliveries.size }
    end

    it 'sends nothing when the expert is revoked from the procedure' do
      procedures.individual.update!(experts_require_administrateur_invitation: true)
      experts_procedures.default.update!(revoked_at: Time.zone.now)

      expect { subject }.not_to change { ActionMailer::Base.deliveries.size }
    end
  end
end
