# frozen_string_literal: true

describe DossierSearchableConcern do
  let(:champ_public) { dossier.project_champs_public.first }
  let(:champ_private) { dossier.project_champs_private.first }

  describe '#index_search_terms' do
    let(:etablissement) { dossier.etablissement }
    let(:dossier) { create(:dossier, :with_entreprise, user: user) }
    let(:etablissement) { build(:etablissement, entreprise_nom: 'Dupont', entreprise_prenom: 'Thomas', association_rna: '12345', association_titre: 'asso de test', association_objet: 'tests unitaires') }
    let(:procedure) { create(:procedure, :with_type_de_champ, :with_type_de_champ_private) }
    let(:dossier) { create(:dossier, etablissement: etablissement, user: user, procedure: procedure) }
    let(:france_connect_information) { build(:france_connect_information, given_name: 'Chris', family_name: 'Harrisson') }
    let(:user) { build(:user, france_connect_informations: [france_connect_information]) }

    let(:result) do
      Dossier.connection.execute(
        Dossier.sanitize_sql_array(["SELECT search_terms, private_search_terms FROM dossiers WHERE id = :id", id: dossier.id])
      ).first
    end

    it "update columns" do
      champ_public.update_attribute(:value, "champ public")
      champ_private.update_attribute(:value, "champ privé")
      perform_enqueued_jobs(only: DossierIndexSearchTermsJob)

      expect(result["search_terms"]).to eq("#{user.email} champ public #{etablissement.entreprise_siren} #{etablissement.entreprise_numero_tva_intracommunautaire} #{etablissement.entreprise_forme_juridique} #{etablissement.entreprise_forme_juridique_code} #{etablissement.entreprise_nom_commercial} #{etablissement.entreprise_raison_sociale} #{etablissement.entreprise_siret_siege_social} #{etablissement.entreprise_nom} #{etablissement.entreprise_prenom} #{etablissement.association_rna} #{etablissement.association_titre} #{etablissement.association_objet} #{etablissement.siret} #{etablissement.naf} #{etablissement.libelle_naf} #{etablissement.adresse} #{etablissement.code_postal} #{etablissement.localite} #{etablissement.code_insee_localite}")
      expect(result["private_search_terms"]).to eq('champ privé')
    end

    context 'with an update' do
      before do
        stub_const("DossierSearchableConcern::SEARCH_TERMS_DEBOUNCE_LIGHT_USER", 1.second)

        # dossier creation trigger a first indexation and flag,
        # so we we have to remove this flag
        dossier.debounce_index_search_terms_flag.remove
      end

      it "update columns en construction" do
        dossier.public_champ_for_update(champ_public.public_id, updated_by: 'test').tap { _1.assign_attributes(value: 'nouvelle valeur publique') }
        dossier.private_champ_for_update(champ_private.public_id, updated_by: 'test').tap { _1.assign_attributes(value: 'nouvelle valeur privee') }

        assert_enqueued_jobs(1, only: DossierIndexSearchTermsJob) do
          dossier.save!
          dossier.passer_en_construction
        end

        perform_enqueued_jobs(only: DossierIndexSearchTermsJob)

        expect(result["search_terms"]).to include('nouvelle valeur publique')
        expect(result["private_search_terms"]).to include('nouvelle valeur privee')
      end

      it "debounce jobs" do
        assert_enqueued_jobs(1, only: DossierIndexSearchTermsJob) do
          3.times { dossier.index_search_terms_later }
        end

        # wait redis key expiration
        sleep 1.01.seconds

        assert_enqueued_jobs(1, only: DossierIndexSearchTermsJob) do
          dossier.index_search_terms_later
        end
      end
    end

    context 'mandataire' do
      it "update columns" do
        dossier.debounce_index_search_terms_flag.remove

        assert_enqueued_jobs(1, only: DossierIndexSearchTermsJob) do
          dossier.update!(mandataire_first_name: "Chris")
        end

        perform_enqueued_jobs(only: DossierIndexSearchTermsJob)

        expect(result["search_terms"]).to include("Chris")
      end
    end
  end

  describe '#index_search_terms_later' do
    let(:user) { create(:user) }
    let(:dossier) { create(:dossier, :brouillon, user: user) }

    before { dossier.debounce_index_search_terms_flag.remove }

    context 'when dossier is brouillon and user has 5 or fewer dossiers' do
      it 'enqueues with a 1 hour delay' do
        freeze_time do
          expect { dossier.index_search_terms_later }
            .to have_enqueued_job(DossierIndexSearchTermsJob)
            .with(dossier)
            .at(1.hour.from_now)
        end
      end
    end

    context 'when dossier is brouillon and user has more than 5 dossiers' do
      before { create_list(:dossier, 5, user: user) }

      it 'enqueues with a 5 minutes delay' do
        freeze_time do
          expect { dossier.index_search_terms_later }
            .to have_enqueued_job(DossierIndexSearchTermsJob)
            .with(dossier)
            .at(5.minutes.from_now)
        end
      end
    end
  end

  describe 'on destroy' do
    let(:user) { create(:user) }
    let(:dossier) { create(:dossier, :brouillon, user: user) }

    before { dossier.debounce_index_search_terms_flag.remove }

    it 'does not enqueue an indexing job' do
      assert_enqueued_jobs(0, only: DossierIndexSearchTermsJob) do
        dossier.destroy
      end
    end
  end

  describe 'after passer_en_construction' do
    let(:user) { create(:user) }
    let(:dossier) { create(:dossier, :brouillon, user: user) }

    before { dossier.debounce_index_search_terms_flag.remove }

    it 'resets debounce flag and enqueues a fresh job with a 5 minutes delay' do
      dossier.debounce_index_search_terms_flag.mark(expires_in: 1.hour)

      freeze_time do
        expect { dossier.passer_en_construction }
          .to have_enqueued_job(DossierIndexSearchTermsJob)
          .with(dossier)
          .at(5.minutes.from_now)
      end
    end
  end
end
