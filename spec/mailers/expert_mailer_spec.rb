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
end
