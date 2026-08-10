# frozen_string_literal: true

RSpec.describe Types::DemarcheType, type: :graphql do
  let(:admin) { administrateurs.default }
  let(:admin_2) { create(:administrateur) }
  let(:query) { '' }
  let(:context) { { administrateur_id: admin.id, procedure_ids: admin.procedure_ids, write_access: true, remote_ip: '192.168.1.23' } }
  let(:variables) { {} }

  subject { API::V2::Schema.execute(query, variables: variables, context: context) }

  let(:data) { subject['data'].deep_symbolize_keys }
  let(:errors) { subject['errors'].deep_symbolize_keys }

  describe 'context should correctly preserve demarche authorization state' do
    let(:query) { DEMARCHE_QUERY }
    let(:procedure) { create(:procedure, administrateurs: [admin]) }

    let(:other_admin_procedure) { create(:procedure) }
    let(:variables) { { number: procedure.id } }

    it do
      result = API::V2::Schema.execute(query, variables: variables, context: context)
      graphql_context = result.context

      expect(graphql_context.authorized_demarche?(procedure)).to be_truthy
      expect(graphql_context.authorized_demarche?(other_admin_procedure)).to be_falsey
    end
  end

  describe 'demarche with clone' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :yes_no }], administrateurs: [admin]) }
    let(:procedure_clone) { procedure.clone(admin:) }
    let(:query) { DEMARCHE_WITH_CHAMP_DESCRIPTORS_QUERY }
    let(:variables) { { number: procedure_clone.id } }
    let(:champ_descriptor_id) { procedure.draft_revision.root_public_types_de_champ.first.to_typed_id }

    it {
      expect(data[:demarche][:champDescriptors]).to eq(data[:demarche][:draftRevision][:champDescriptors])
      expect(data[:demarche][:champDescriptors][0][:id]).to eq(champ_descriptor_id)
      expect(data[:demarche][:draftRevision][:champDescriptors][0][:id]).to eq(champ_descriptor_id)
      expect(procedure.draft_revision.root_public_types_de_champ.first.id).not_to eq(procedure_clone.draft_revision.root_public_types_de_champ.first.id)
      expect(procedure.draft_revision.root_public_types_de_champ.first.stable_id).to eq(procedure_clone.draft_revision.root_public_types_de_champ.first.stable_id)
    }
  end

  describe 'add administrateur' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :yes_no }], administrateurs: [admin]) }
    let(:query) { ADD_ADMINISTRATEUR_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, email: admin_2.email } }

    it do
      expect(procedure.administrateurs.count).to eq(1)
      expect(procedure.administrateurs[0]).to eq(admin)
      expect(data[:demarcheAjouterAdministrateur][:errors]).to eq(nil)
      procedure.reload
      expect(procedure.administrateurs.count).to eq(2)
      expect(procedure.administrateurs[0]).to eq(admin)
      expect(procedure.administrateurs[1]).to eq(admin_2)
    end
  end

  describe 'add administrateur missing right' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :yes_no }], administrateurs: [admin]) }
    let(:query) { ADD_ADMINISTRATEUR_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, email: admin_2.email } }
    let(:context) { { administrateur_id: admin_2.id, procedure_ids: admin_2.procedure_ids, write_access: true } }

    it do
      expect(procedure.administrateurs.count).to eq(1)
      expect(procedure.administrateurs[0]).to eq(admin)
      expect(data[:demarcheAjouterAdministrateur][:errors]).to eq([{ message: "Vous n'avez pas le droit d'ajouter un administrateur sur la démarche" }])
      expect(procedure.administrateurs.count).to eq(1)
      expect(procedure.administrateurs[0]).to eq(admin)
    end
  end

  describe 'add new administrateur without right ip' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :yes_no }], administrateurs: [admin]) }
    let(:query) { ADD_ADMINISTRATEUR_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, email: "no-admin@admin.com" } }

    before do
      allow(ENV).to receive(:fetch).with('CREATE_ADMINISTRATEUR_BY_API_AUTHORIZED_NETWORKS', '').and_return('203.0.113.0/24')
    end
    it do
      expect(procedure.administrateurs.count).to eq(1)
      expect(procedure.administrateurs[0]).to eq(admin)
      expect(data[:demarcheAjouterAdministrateur][:warnings]).to eq([{ message: "no-admin@admin.com n’est pas associé à un compte administrateur" }])
      expect(procedure.administrateurs.count).to eq(1)
      expect(procedure.administrateurs[0]).to eq(admin)
    end
  end

  describe 'add new administrateur with right ip' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :yes_no }], administrateurs: [admin]) }
    let(:query) { ADD_ADMINISTRATEUR_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, email: "no-admin@admin.com" } }

    before do
      allow(ENV).to receive(:fetch).with('CREATE_ADMINISTRATEUR_BY_API_AUTHORIZED_NETWORKS', '').and_return('192.0.0.0/8')
    end
    it do
      expect(procedure.administrateurs.count).to eq(1)
      expect(procedure.administrateurs[0]).to eq(admin)
      expect(data[:demarcheAjouterAdministrateur][:warnings].count).to eq(0)
      procedure.reload
      expect(procedure.administrateurs.count).to eq(2)
      expect(procedure.administrateurs.map(&:email)).to match_array([admin.email, 'no-admin@admin.com'])
    end
  end

  describe 'remove administrateur' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :yes_no }], administrateurs: [admin]) }

    let(:query) { REMOVE_ADMINISTRATEUR_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, email: admin_2.email } }

    before do
      procedure.administrateurs_procedures.create(administrateur: admin_2)
    end

    it do
      expect(procedure.administrateurs.count).to eq(2)
      expect(procedure.administrateurs[0]).to eq(admin)
      expect(procedure.administrateurs[1]).to eq(admin_2)
      expect(data[:demarcheSupprimerAdministrateur][:errors]).to eq(nil)
      procedure.reload
      expect(procedure.administrateurs.count).to eq(1)
      expect(procedure.administrateurs[0]).to eq(admin)
    end
  end

  describe 'remove administrateur missing right' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :yes_no }], administrateurs: [admin]) }
    let(:query) { REMOVE_ADMINISTRATEUR_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, email: admin_2.email } }
    let(:context) { { administrateur_id: admin_2.id, procedure_ids: admin_2.procedure_ids, write_access: true } }

    it do
      expect(procedure.administrateurs.count).to eq(1)
      expect(procedure.administrateurs[0]).to eq(admin)
      expect(data[:demarcheSupprimerAdministrateur][:errors]).to eq([{ message: "Vous n'avez pas le droit de retirer un administrateur sur la démarche" }])
      expect(procedure.administrateurs.count).to eq(1)
      expect(procedure.administrateurs[0]).to eq(admin)
    end
  end

  describe 'publier une demarche' do
    let(:procedure) { create(:procedure, administrateurs: [admin]) }
    let(:query) { PUBLIER_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, path: 'test-path', lienSiteWeb: 'https://test.gouv.fr' } }

    it do
      expect(procedure).to be_brouillon
      expect(data[:demarchePublier][:errors]).to eq(nil)
      expect(data[:demarchePublier][:demarche][:state]).to eq('publiee')
      procedure.reload
      expect(procedure).to be_publiee
      expect(procedure.path).to eq('test-path')
      expect(procedure.lien_site_web).to eq('https://test.gouv.fr')
      expect(procedure.robots_indexable).to be(true)
    end
  end

  describe 'publier une demarche non referencable par les moteurs de recherche' do
    let(:procedure) { create(:procedure, administrateurs: [admin]) }
    let(:query) { PUBLIER_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, path: 'test-path', lienSiteWeb: 'https://test.gouv.fr', robotsIndexable: false } }

    it do
      expect(data[:demarchePublier][:errors]).to eq(nil)
      procedure.reload
      expect(procedure).to be_publiee
      expect(procedure.robots_indexable).to be(false)
    end
  end

  describe 'republier une demarche depubliee' do
    let(:procedure) { procedures.depubliee }
    let(:query) { PUBLIER_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, path: procedure.path, lienSiteWeb: 'https://test.gouv.fr' } }

    it do
      expect(procedure).to be_depubliee
      expect(data[:demarchePublier][:errors]).to eq(nil)
      expect(data[:demarchePublier][:demarche][:state]).to eq('publiee')
      procedure.reload
      expect(procedure).to be_publiee
    end
  end

  describe 'publier une demarche sans droit' do
    let(:procedure) { create(:procedure, administrateurs: [admin]) }
    let(:query) { PUBLIER_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, path: 'test-path', lienSiteWeb: 'https://test.gouv.fr' } }
    let(:context) { { administrateur_id: admin_2.id, procedure_ids: admin_2.procedure_ids, write_access: true } }

    it do
      expect(data[:demarchePublier][:errors]).to eq([{ message: "La démarche \"#{procedure.id}\" n'existe pas ou vous n'avez pas le droit de la publier." }])
      procedure.reload
      expect(procedure).to be_brouillon
    end
  end

  describe 'publier une demarche avec un chemin appartenant a un autre administrateur' do
    let(:other_procedure) { create(:procedure, :published, administrateurs: [admin_2]) }
    let(:procedure) { create(:procedure, administrateurs: [admin]) }
    let(:query) { PUBLIER_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, path: other_procedure.path, lienSiteWeb: 'https://test.gouv.fr' } }

    it do
      expect(data[:demarchePublier][:errors]).to eq([{ message: "Le champ « Lien public » est déjà utilisé par une démarche. Vous ne pouvez pas l’utiliser car il appartient à un autre administrateur." }])
      procedure.reload
      expect(procedure).to be_brouillon
    end
  end

  describe 'publier une demarche en remplacant une autre du meme administrateur' do
    let(:other_procedure) { create(:procedure, :published, administrateurs: [admin]) }
    let(:procedure) { create(:procedure, administrateurs: [admin]) }
    let(:query) { PUBLIER_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, path: other_procedure.path, lienSiteWeb: 'https://test.gouv.fr' } }

    it do
      expect(data[:demarchePublier][:errors]).to eq(nil)
      expect(data[:demarchePublier][:demarche][:state]).to eq('publiee')
      procedure.reload
      other_procedure.reload
      expect(procedure).to be_publiee
      expect(procedure.path).to eq(variables[:path])
      expect(other_procedure).to be_depubliee
    end
  end

  describe 'publier une demarche sans lien_site_web' do
    let(:procedure) { create(:procedure, administrateurs: [admin], lien_site_web: nil) }
    let(:query) { PUBLIER_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, path: 'test-path' } }

    it do
      expect(data[:demarchePublier][:errors]).to eq([{ message: "L'information \"Où trouver la démarche\" est obligatoire (\"lienSiteWeb\")." }])
      procedure.reload
      expect(procedure).to be_brouillon
    end
  end

  describe 'publier une demarche deja publiee' do
    let(:procedure) { create(:procedure, :published, administrateurs: [admin]) }
    let(:query) { PUBLIER_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, path: procedure.path, lienSiteWeb: 'https://test.gouv.fr' } }

    it do
      expect(data[:demarchePublier][:warnings]).to eq([{ message: "La démarche \"#{procedure.id}\" est déjà publiée ou cloturée." }])
      expect(data[:demarchePublier][:demarche]).to eq(nil)
      procedure.reload
      expect(procedure).to be_publiee
    end
  end

  describe 'publier une demarche avec un chemin au format invalide' do
    let(:procedure) { create(:procedure, administrateurs: [admin]) }
    let(:query) { PUBLIER_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, path: 'test-path-', lienSiteWeb: 'https://test.gouv.fr' } }

    it do
      expect(data[:demarchePublier][:errors]).to eq([{ message: "Le champ « Lien public » doit se terminer par une lettre ou un chiffre." }])
      procedure.reload
      expect(procedure).to be_brouillon
    end
  end

  describe 'publier une demarche dont le brouillon est invalide' do
    let(:procedure) { create(:procedure, administrateurs: [admin], monavis_embed: 'invalide') }
    let(:query) { PUBLIER_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, path: 'test-path', lienSiteWeb: 'https://test.gouv.fr' } }

    it do
      expect(data[:demarchePublier][:errors]).to eq([{ message: "Le code MonAvis doit comporter un lien" }, { message: "Le code MonAvis doit comporter une image" }])
      procedure.reload
      expect(procedure).to be_brouillon
    end
  end

  DEMARCHE_QUERY = <<-GRAPHQL
  query($number: Int!) {
    demarche(number: $number) {
      number
    }
  }
  GRAPHQL

  DEMARCHE_WITH_CHAMP_DESCRIPTORS_QUERY = <<-GRAPHQL
  query($number: Int!) {
    demarche(number: $number) {
      number
      champDescriptors {
        id
        label
      }
      draftRevision {
        champDescriptors {
          id
          label
        }
      }
    }
  }
  GRAPHQL

  ADD_ADMINISTRATEUR_DEMARCHE_QUERY = <<-GRAPHQL
  mutation AjouterAdmin($demarcheNumber: Int!, $email: String!) {
    demarcheAjouterAdministrateur(
      input: {demarche: {number: $demarcheNumber}, administrateurs: [{ email: $email }] }
    ) {
      clientMutationId
      demarche {
        id
      }
      warnings {
        message
      }
      errors {
        message
      }
    }
  }
  GRAPHQL

  REMOVE_ADMINISTRATEUR_DEMARCHE_QUERY = <<-GRAPHQL
  mutation SupprimerAdmin($demarcheNumber: Int!, $email: String!) {
    demarcheSupprimerAdministrateur(
      input: {demarche: {number: $demarcheNumber}, administrateurs: [{ email: $email }] }
    ) {
      clientMutationId
      demarche {
        id
      }
      errors {
        message
      }
    }
  }
  GRAPHQL

  describe 'modifier parametres' do
    let(:procedure) { create(:procedure, administrateurs: [admin]) }
    let(:query) { MODIFIER_PARAMETRES_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, title: 'Nouveau titre' } }

    it 'met à jour le titre' do
      expect(data[:demarcheModifierParametres][:errors]).to eq(nil)
      expect(data[:demarcheModifierParametres][:demarche][:title]).to eq('Nouveau titre')
      procedure.reload
      expect(procedure.libelle).to eq('Nouveau titre')
    end
  end

  describe 'modifier parametres sans droit' do
    let(:procedure) { create(:procedure, administrateurs: [admin]) }
    let(:query) { MODIFIER_PARAMETRES_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, title: 'Nouveau titre' } }
    let(:context) { { administrateur_id: admin_2.id, procedure_ids: admin_2.procedure_ids, write_access: true } }

    it 'retourne une erreur' do
      expect(data[:demarcheModifierParametres][:errors]).to eq([{ message: "La démarche \"#{procedure.id}\" n'existe pas ou vous n'avez pas le droit de la modifier." }])
      procedure.reload
      expect(procedure.libelle).not_to eq('Nouveau titre')
    end
  end

  describe 'modifier parametres sans aucun parametre' do
    let(:procedure) { create(:procedure, administrateurs: [admin]) }
    let(:query) { MODIFIER_PARAMETRES_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id } }

    it 'retourne une erreur' do
      expect(data[:demarcheModifierParametres][:errors]).to eq([{ message: 'Aucun paramètre à modifier.' }])
    end
  end

  describe 'modifier parametres avec une date limite dans le passé' do
    let(:procedure) { create(:procedure, administrateurs: [admin]) }
    let(:query) { MODIFIER_PARAMETRES_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, dateLimite: 1.day.ago.to_date.iso8601 } }

    it 'retourne une erreur' do
      expect(data[:demarcheModifierParametres][:errors]).to eq([{ message: 'La date limite doit être dans le futur.' }])
      procedure.reload
      expect(procedure.auto_archive_on).to be_nil
    end
  end

  describe 'modifier tous les parametres' do
    let(:procedure) { create(:procedure, administrateurs: [admin]) }
    let(:query) { MODIFIER_PARAMETRES_DEMARCHE_QUERY }
    let(:future_date) { 1.month.from_now.to_date }
    let(:variables) do
      {
        demarcheNumber: procedure.id,
        title: 'Nouveau titre',
        description: 'Nouvelle description',
        descriptionTargetAudience: 'Nouveau public cible',
        descriptionPj: 'Nouvelles pièces jointes',
        lienSiteWeb: 'https://nouveau-site.gouv.fr',
        lienDpo: 'dpo@nouveau-site.gouv.fr',
        dateLimite: future_date.iso8601,
        declarative: 'accepte',
      }
    end

    it 'met à jour tous les champs' do
      expect(data[:demarcheModifierParametres][:errors]).to eq(nil)
      expect(data[:demarcheModifierParametres][:demarche][:dateLimite]).to eq(future_date.iso8601)
      procedure.reload
      expect(procedure.libelle).to eq('Nouveau titre')
      expect(procedure.description).to eq('Nouvelle description')
      expect(procedure.description_target_audience).to eq('Nouveau public cible')
      expect(procedure.description_pj).to eq('Nouvelles pièces jointes')
      expect(procedure.lien_site_web).to eq('https://nouveau-site.gouv.fr')
      expect(procedure.lien_dpo).to eq('dpo@nouveau-site.gouv.fr')
      expect(procedure.auto_archive_on).to eq(future_date)
      expect(procedure.declarative_with_state).to eq('accepte')
    end
  end

  describe 'modifier parametres declarative non_declarative' do
    let(:procedure) { create(:procedure, administrateurs: [admin], declarative_with_state: 'accepte') }
    let(:query) { MODIFIER_PARAMETRES_DEMARCHE_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, declarative: 'non_declarative' } }

    it 'remet declarative_with_state à nil' do
      expect(data[:demarcheModifierParametres][:errors]).to eq(nil)
      expect(data[:demarcheModifierParametres][:demarche][:declarative]).to eq(nil)
      procedure.reload
      expect(procedure.declarative_with_state).to be_nil
    end
  end

  MODIFIER_PARAMETRES_DEMARCHE_QUERY = <<-GRAPHQL
  mutation ModifierParametres($demarcheNumber: Int!, $title: String, $description: String, $descriptionTargetAudience: String, $descriptionPj: String, $lienSiteWeb: String, $lienDpo: String, $dateLimite: ISO8601Date, $declarative: DeclarativeWithState) {
    demarcheModifierParametres(
      input: { demarche: { number: $demarcheNumber }, title: $title, description: $description, descriptionTargetAudience: $descriptionTargetAudience, descriptionPj: $descriptionPj, lienSiteWeb: $lienSiteWeb, lienDpo: $lienDpo, dateLimite: $dateLimite, declarative: $declarative }
    ) {
      demarche {
        title
        declarative
        dateLimite
      }
      errors {
        message
      }
    }
  }
  GRAPHQL

  PUBLIER_DEMARCHE_QUERY = <<-GRAPHQL
  mutation PublierDemarche($demarcheNumber: Int!, $path: String!, $lienSiteWeb: String, $robotsIndexable: Boolean) {
    demarchePublier(
      input: { demarche: { number: $demarcheNumber }, path: $path, lienSiteWeb: $lienSiteWeb, robotsIndexable: $robotsIndexable }
    ) {
      demarche {
        id
        state
      }
      errors {
        message
      }
      warnings {
        message
      }
    }
  }
  GRAPHQL
end
