# frozen_string_literal: true

RSpec.describe GroupeGestionnaireMailer, type: :mailer do
  describe '#notify_removed_gestionnaire' do
    let(:groupe_gestionnaire) { create(:groupe_gestionnaire) }

    let(:gestionnaire_to_remove) { create(:gestionnaire, email: 'int3@g.fr') }

    let(:current_super_admin_email) { 'toto@email.com' }

    subject { described_class.notify_removed_gestionnaire(groupe_gestionnaire, gestionnaire_to_remove.email, current_super_admin_email) }

    it do
      expect(subject.body).to include('Vous venez d’être supprimé(e) du groupe gestionnaire')
      expect(subject.to).to match_array(['int3@g.fr'])
    end
  end

  describe '#notify_added_gestionnaires' do
    let(:groupe_gestionnaire) { create(:groupe_gestionnaire) }

    let(:gestionnaires_to_add) { [create(:gestionnaire, email: 'int3@g.fr'), create(:gestionnaire, email: 'int4@g.fr')] }

    let(:current_super_admin_email) { 'toto@email.com' }

    subject { described_class.notify_added_gestionnaires(groupe_gestionnaire, gestionnaires_to_add, current_super_admin_email) }

    before { gestionnaires_to_add.each { groupe_gestionnaire.add_gestionnaire(_1) } }

    it do
      expect(subject.body).to include('Vous venez d’être nommé gestionnaire du groupe gestionnaire')
      expect(subject.bcc).to match_array(['int3@g.fr', 'int4@g.fr'])
    end
  end

  describe '#notify_removed_administrateur' do
    let(:groupe_gestionnaire) { create(:groupe_gestionnaire) }

    let(:administrateur_to_remove) { create(:administrateur, email: 'int3@g.fr') }

    let(:current_super_admin_email) { 'toto@email.com' }

    subject { described_class.notify_removed_administrateur(groupe_gestionnaire, administrateur_to_remove.email, current_super_admin_email) }

    it do
      expect(subject.body).to include('Vous venez d’être supprimé(e) du groupe gestionnaire')
      expect(subject.to).to match_array(['int3@g.fr'])
    end
  end

  describe '#notify_added_administrateurs' do
    let(:groupe_gestionnaire) { create(:groupe_gestionnaire) }

    let(:administrateurs_to_add) { [create(:administrateur, email: 'int3@g.fr'), create(:administrateur, email: 'int4@g.fr')] }

    let(:current_super_admin_email) { 'toto@email.com' }

    subject { described_class.notify_added_administrateurs(groupe_gestionnaire, administrateurs_to_add, current_super_admin_email) }

    before { administrateurs_to_add.each { groupe_gestionnaire.add_administrateur(_1) } }

    it do
      expect(subject.body).to include("Vous venez d’être nommé administrateur du groupe gestionnaire #{groupe_gestionnaire.name}")
      expect(subject.body).to include("par « #{current_super_admin_email} »")
      expect(subject.bcc).to match_array(['int3@g.fr', 'int4@g.fr'])
    end
  end

  describe '#notify_new_commentaire_groupe_gestionnaire' do
    let(:groupe_gestionnaire) { create(:groupe_gestionnaire) }

    let(:gestionnaire) { create(:gestionnaire, email: 'int3@g.fr') }

    let(:admin) { create(:administrateur, email: 'toto@email.com') }

    let(:commentaire) { create(:commentaire_groupe_gestionnaire, sender: admin) }

    let(:commentaire_url) { gestionnaire_groupe_gestionnaire_commentaire_url(groupe_gestionnaire, commentaire) }

    subject { described_class.notify_new_commentaire_groupe_gestionnaire(groupe_gestionnaire, commentaire, admin.email, gestionnaire.email, commentaire_url) }

    it do
      expect(subject.body).to include('Vous avez un nouveau message dans le groupe gestionnaire')
      expect(subject.to).to match_array(['int3@g.fr'])
    end
  end
end
