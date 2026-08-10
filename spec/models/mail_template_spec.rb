# frozen_string_literal: true

describe Mails::InitiatedMail, type: :model do
  let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :text, libelle: 'nom' }]) }
  let(:type_de_champ) { procedure.draft_revision.root_public_types_de_champ.first }
  let(:mail) { described_class.default_for_procedure(procedure) }

  let(:email_subject) { '' }
  let(:email_body) { '' }

  subject do
    mail.subject = email_subject
    mail.body = email_body
    mail.validate
    mail
  end

  describe 'body' do
    context 'empty template' do
      it { expect(subject.errors).to be_empty }
    end

    context 'template with valid tag' do
      let(:email_body) { 'foo --numéro du dossier-- bar' }

      it { expect(subject.errors).to be_empty }
    end

    context 'template with new valid tag' do
      let(:email_body) { 'foo --age-- bar' }

      before do
        procedure.draft_revision.add_type_de_champ(type_champ: :integer_number, libelle: 'age')
        procedure.publish_revision!(procedure.administrateurs.first)
      end

      it { expect(subject.errors).to be_empty }
    end

    context 'template with invalid tag' do
      let(:email_body) { 'foo --numéro du -- bar' }

      it { expect(subject.errors.full_messages).to eq(["Le champ « Corps de l’email » contient la balise \"numéro du\" qui n’existe pas. Supprimer la balise"]) }
    end

    context 'template with unpublished tag' do
      let(:email_body) { 'foo --age-- bar' }

      before do
        procedure.draft_revision.add_type_de_champ(type_champ: :integer_number, libelle: 'age')
      end

      it { expect(subject.errors.full_messages).to eq(["Le champ « Corps de l’email » contient la balise \"age\" qui n’est pas encore publiée. Publier la nouvelle version de la démarche et recommencer"]) }
    end

    context 'template with removed but unpublished tag' do
      let(:email_body) { 'foo --nom-- bar' }

      before do
        procedure.draft_revision.remove_type_de_champ(type_de_champ.stable_id)
      end

      it { expect(subject.errors.full_messages).to eq(["Le champ « Corps de l’email » contient la balise \"nom\" qui a été supprimée mais la suppression n’est pas encore publiée. Publier la nouvelle version de la démarche et recommencer"]) }
    end

    context 'template with removed tag' do
      let(:email_body) { 'foo --nom-- bar' }

      before do
        procedure.draft_revision.remove_type_de_champ(type_de_champ.stable_id)
        procedure.publish_revision!(procedure.administrateurs.first)
      end

      it { expect(subject.errors.full_messages).to eq(["Le champ « Corps de l’email » contient la balise \"nom\" qui a été supprimée. Supprimer la balise"]) }
    end

    context 'template with new tag and old dossier' do
      let(:email_body) { 'foo --age-- bar' }

      before do
        create(:dossier, :en_construction, procedure: procedure)
        procedure.draft_revision.add_type_de_champ(type_champ: :integer_number, libelle: 'age')
        procedure.publish_revision!(procedure.administrateurs.first)
      end

      it { expect(subject.errors.full_messages).to eq(["Le champ « Corps de l’email » contient la balise \"age\" qui n’existe pas sur un des dossiers en cours de traitement. Supprimer la balise"]) }
    end
  end
end
