# frozen_string_literal: true

describe 'shared/dossiers/demande', type: :view do
  let(:current_instructeur) { create(:instructeur) }
  let(:individual) { nil }
  let(:etablissement) { nil }
  let(:procedure) { create(:procedure, :published) }
  let(:dossier) { create(:dossier, :en_construction, procedure: procedure, etablissement: etablissement, individual: individual) }

  before do
    sign_in(current_instructeur.user)
  end

  subject { render 'shared/dossiers/demande', dossier: dossier, demande_seen_at: nil, profile: 'usager' }

  context 'when dossier was created by an etablissement' do
    let(:etablissement) { create(:etablissement) }

    it 'renders the etablissement infos' do
      expect(subject).to include(etablissement.entreprise_raison_sociale)
      expect(subject).to include(etablissement.entreprise_siret_siege_social)
      expect(subject).to include(etablissement.entreprise_forme_juridique)
    end

    context 'and entreprise is an association' do
      let(:etablissement) { create(:etablissement, :is_association) }

      it 'renders the association infos' do
        expect(subject).to include(etablissement.association_rna)
        expect(subject).to include(etablissement.association_titre)
        expect(subject).to include(etablissement.association_objet)
      end
    end
  end

  context 'when dossier was created by an individual' do
    let(:individual) { build(:individual) }

    it 'renders the individual identity infos' do
      expect(subject).to include(individual.gender)
      expect(subject).to include(individual.nom)
      expect(subject).to include(individual.prenom)
      expect(subject).to include(I18n.l(individual.birthdate, format: :long))
    end
  end

  context 'when the dossier has champs' do
    let(:procedure) { create(:procedure, :published, :with_type_de_champ) }

    it 'renders the champs' do
      dossier.project_champs_public.each do |champ|
        expect(subject).to include(champ.libelle)
      end
    end
  end

  context 'when a champ is freshly build' do
    let(:procedure) { create(:procedure, :published, :with_type_de_champ) }
    before do
      dossier.project_champs_public.first.champ_data.destroy
      dossier.reload
    end

    it 'renders without error' do
      procedure.active_revision.types_de_champ.each do |tdc|
        expect(subject).to include(tdc.libelle)
      end
    end
  end
end
