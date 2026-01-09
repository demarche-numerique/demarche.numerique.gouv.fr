# frozen_string_literal: true

describe API::V1::DossiersController do
  let(:admin) { administrateurs(:default_admin) }
  let(:token) { APIToken.generate(admin)[1] }
  let(:procedure) { create(:procedure, :with_type_de_champ, :with_type_de_champ_private, administrateur: admin) }
  let(:wrong_procedure) { create(:procedure, :new_administrateur) }

  it { expect(described_class).to be < APIController }

  describe 'GET index (with bearer token)' do
    let(:authorization_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }
    let(:retour) do
      request.env['HTTP_AUTHORIZATION'] = authorization_header
      get :index, params: { procedure_id: procedure_id }
    end

    subject { retour }

    context 'when procedure is not found' do
      let(:procedure_id) { 99_999_999 }
      it { expect(subject.code).to eq('404') }
    end
  end

  describe 'GET index' do
    let(:order) { nil }
    let(:retour) { get :index, params: { token: token, procedure_id: procedure_id, order: order }.compact }

    subject { retour }

    context 'when procedure is not found' do
      let(:procedure_id) { 99_999_999 }
      it { expect(subject.code).to eq('404') }
    end

    context 'when procedure does not belong to admin' do
      let(:procedure_id) { wrong_procedure.id }
      it { expect(subject.code).to eq('404') }
    end

    context 'when procedure is found and belongs to admin' do
      let(:procedure_id) { procedure.id }
      let(:date_creation) { Time.zone.local(2008, 9, 1, 10, 5, 0) }
      let!(:dossier) { travel_to(date_creation) { create(:dossier, :with_entreprise, :en_construction, procedure: procedure) } }
      let(:body) { JSON.parse(retour.body, symbolize_names: true) }

      it do
        expect(retour.code).to eq('200')
        expect(body).to have_key :pagination
        expect(body).to have_key :dossiers
      end

      context 'but the token is invalid' do
        let(:token) { 'bad' }

        it { expect(subject.code).to eq('401') }
      end

      describe 'pagination' do
        subject { body[:pagination] }
        it do
          expect(subject[:page]).to eq(1)
          expect(subject[:resultats_par_page]).to eq(described_class.const_get(:DEFAULT_PAGE_SIZE))
          expect(subject[:nombre_de_page]).to eq(1)
        end
      end

      describe 'with custom resultats_par_page' do
        let(:retour) { get :index, params: { token: token, procedure_id: procedure_id, resultats_par_page: 18 } }
        subject { body[:pagination] }
        it { expect(subject[:resultats_par_page]).to eq(18) }
      end

      describe 'dossiers' do
        subject { body[:dossiers] }
        it { expect(subject).to be_an(Array) }
        describe 'dossier' do
          subject { super().first }

          it do
            expect(subject[:id]).to eq(dossier.id)
            expect(subject[:updated_at]).to eq("2008-09-01T08:05:00.000Z")
            expect(subject[:initiated_at]).to eq("2008-09-01T07:56:00.000Z")
            expect(subject[:state]).to eq("initiated")
            expect(subject.keys.size).to eq(4)
          end
        end

        describe 'order' do
          let!(:dossier1) { create(:dossier, :with_entreprise, procedure: procedure, state: Dossier.states.fetch(:en_construction)) }
          let!(:dossier2) { create(:dossier, :with_entreprise, procedure: procedure, state: Dossier.states.fetch(:en_construction)) }

          context 'asc' do
            let(:order) { 'asc' }

            it { expect(subject.map { |dossier| dossier[:id] }).to eq([dossier.id, dossier1.id, dossier2.id]) }
          end

          context 'desc' do
            let(:order) { 'desc' }

            it { expect(subject.map { |dossier| dossier[:id] }).to eq([dossier2.id, dossier1.id, dossier.id]) }
          end
        end
      end

      context 'when there are multiple pages' do
        let(:retour) { get :index, params: { token: token, procedure_id: procedure_id, page: 2 } }

        let!(:dossier1) { create(:dossier, :with_entreprise, procedure: procedure, state: Dossier.states.fetch(:en_construction)) }
        let!(:dossier2) { create(:dossier, :with_entreprise, procedure: procedure, state: Dossier.states.fetch(:en_construction)) }

        before do
          allow(controller).to receive(:per_page).and_return(1)
        end

        describe 'pagination' do
          subject { body[:pagination] }

          it do
            expect(subject[:page]).to eq(2)
            expect(subject[:resultats_par_page]).to eq(1)
            expect(subject[:nombre_de_page]).to eq(3)
          end
        end
      end
    end
  end

  describe 'GET show' do
    before do
      allow(APIGeoService).to receive(:departement_name).with('01').and_return('Ain')
    end

    let(:retour) { get :show, params: { token: token, procedure_id: procedure_id, id: dossier_id } }
    subject { retour }

    context 'when procedure is not found' do
      let(:procedure_id) { 99_999_999 }
      let(:dossier_id) { 1 }
      it { expect(subject.code).to eq('404') }
    end

    context 'when procedure exists and does not belong to current admin' do
      let(:procedure_id) { wrong_procedure.id }
      let(:dossier_id) { 1 }
      it { expect(subject.code).to eq('404') }
    end

    context 'when procedure is found and belongs to current admin' do
      context 'when dossier does not exist' do
        let(:procedure_id) { procedure.id }
        let(:dossier_id) { 99999 }
        it { expect(subject.code).to eq('404') }
      end

      context 'when dossier exists but does not belong to procedure' do
        let(:procedure_id) { procedure.id }
        let(:dossier) { create(:dossier, :with_entreprise, procedure: wrong_procedure) }
        let(:dossier_id) { dossier.id }
        it { expect(subject.code).to eq('404') }
      end

      context 'when dossier (with attestation) exists and belongs to procedure' do
        let(:procedure_id) { procedure.id }
        let(:dossier_id) { dossier.id }
        let!(:dossier) { create(:dossier, :with_entreprise, :with_attestation_acceptation, :accepte, procedure: procedure, motivation: "Motivation") }
        let(:body) { JSON.parse(retour.body, symbolize_names: true) }
        subject { body[:dossier] }

        it {
          expect(retour.code).to eq('200')
          expect(subject[:id]).to eq(dossier.id)
          expect(subject[:state]).to eq('closed')
          expect(subject[:attestation]).to_not be_nil
        }
      end

      context 'when dossier exists and belongs to procedure' do
        let(:procedure_id) { procedure.id }
        let(:date_creation) { Time.zone.local(2008, 9, 1, 10, 5, 0) }
        let!(:dossier) { travel_to(date_creation) { create(:dossier, :with_entreprise, :accepte, procedure: procedure, motivation: "Motivation") } }
        let(:dossier_id) { dossier.id }
        let(:body) { JSON.parse(retour.body, symbolize_names: true) }
        let(:field_list) { [:id, :created_at, :updated_at, :archived, :individual, :entreprise, :etablissement, :cerfa, :types_de_piece_justificative, :pieces_justificatives, :champs, :champs_private, :commentaires, :state, :simplified_state, :initiated_at, :processed_at, :received_at, :motivation, :email, :instructeurs, :attestation, :avis] }
        subject { body[:dossier] }

        it 'return REST code 200', :show_in_doc do
          expect(retour.code).to eq('200')
        end

        it do
          expect(subject[:id]).to eq(dossier.id)
          expect(subject[:state]).to eq('closed')
          expect(subject[:created_at]).to eq('2008-09-01T07:55:00.000Z')
          expect(subject[:updated_at]).to eq('2008-09-01T08:05:00.000Z')
          expect(subject[:archived]).to eq(dossier.archived)
          expect(subject.keys).to match_array(field_list)
        end

        describe 'entreprise' do
          let(:field_list) {
            [
              :siren,
              :capital_social,
              :numero_tva_intracommunautaire,
              :forme_juridique,
              :forme_juridique_code,
              :nom_commercial,
              :raison_sociale,
              :siret_siege_social,
              :code_effectif_entreprise,
              :effectif_mois,
              :effectif_annee,
              :effectif_mensuel,
              :effectif_annuel,
              :effectif_annuel_annee,
              :date_creation,
              :nom,
              :prenom,
            ]
          }
          subject { super()[:entreprise] }

          it do
            expect(subject[:siren]).to eq('440117620')
            expect(subject[:capital_social]).to eq(537_100_000)
            expect(subject[:numero_tva_intracommunautaire]).to eq('FR27440117620')
            expect(subject[:forme_juridique]).to eq('SA à conseil d’administration (s.a.i.)')
            expect(subject[:forme_juridique_code]).to eq('5599')
            expect(subject[:nom_commercial]).to eq('GRTGAZ')
            expect(subject[:raison_sociale]).to eq('GRTGAZ')
            expect(subject[:siret_siege_social]).to eq('44011762001530')
            expect(subject[:code_effectif_entreprise]).to eq('51')
            expect(subject[:date_creation]).to eq('1990-04-24T00:00:00.000+00:00')
            expect(subject.keys).to match_array(field_list)
          end
        end

        describe 'champs' do
          let(:field_list) { [:url] }
          subject { super()[:champs] }

          it { expect(subject.length).to eq 1 }

          describe 'first champ' do
            subject { super().first }

            it do
              expect(subject.key?(:value)).to be_truthy
              expect(subject.key?(:type_de_champ)).to be_truthy
            end

            describe 'type de champ' do
              let(:field_list) {
                [
                  :id,
                  :libelle,
                  :description,
                  :order_place,
                  :type,
                ]
              }
              subject { super()[:type_de_champ] }

              it do
                expect(subject.key?(:id)).to be_truthy
                expect(subject[:libelle]).to include('Libelle du champ')
                expect(subject[:description]).to include('description du champ')
                expect(subject.key?(:order_place)).to be_truthy
                expect(subject[:type_champ]).to eq('text')
              end
            end
          end

          describe 'departement' do
            let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :departements }], administrateur: admin) }
            let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure: procedure) }

            subject { super() }

            it 'should have rows' do
              expect(subject.size).to eq(1)
              expect(subject.first[:value]).to eq("01 – Ain")
            end
          end

          describe 'repetition' do
            let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :repetition, children: [{ type: :text }, { type: :integer_number }] }], administrateur: admin) }
            let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure: procedure) }

            subject { super().first[:rows] }

            it 'should have rows' do
              expect(subject.size).to eq(2)
              expect(subject[0][:id]).to eq(1)
              expect(subject[0][:champs].size).to eq(2)
              expect(subject[0][:champs].map { |c| c[:value] }).to eq(['text', 42])
              expect(subject[0][:champs].map { |c| c[:type_de_champ][:type_champ] }).to eq(['text', 'integer_number'])
            end
          end
        end

        describe 'champs_private' do
          let(:field_list) { [:url] }
          subject { super()[:champs_private] }

          it { expect(subject.length).to eq 1 }

          describe 'first champs' do
            subject { super().first }

            it do
              expect(subject.key?(:value)).to be_truthy
              expect(subject.key?(:type_de_champ)).to be_truthy
            end

            describe 'type de champ' do
              let(:field_list) {
                [
                  :id,
                  :libelle,
                  :description,
                  :order_place,
                  :type,
                ]
              }
              subject { super()[:type_de_champ] }

              it do
                expect(subject.key?(:id)).to be_truthy
                expect(subject[:libelle]).to include('Libelle champ privé')
                expect(subject[:description]).to include('description du champ privé')
                expect(subject.key?(:order_place)).to be_truthy
                expect(subject[:type_champ]).to eq('text')
              end
            end
          end
        end

        describe 'commentaires' do
          let!(:commentaire) { create :commentaire, body: 'plop', created_at: '2016-03-14 14:00:00', email: 'plop@plip.com', dossier: dossier }
          let!(:commentaire_2) { create :commentaire, body: 'plip', created_at: '2016-03-14 15:00:00', email: 'plip@plap.com', dossier: dossier }

          subject { super()[:commentaires] }

          it do
            expect(subject.size).to eq 2
            expect(subject.first[:body]).to eq 'plop'
            expect(subject.first[:created_at]).to eq '2016-03-14T13:00:00.000Z'
            expect(subject.first[:email]).to eq 'plop@plip.com'
          end
        end

        describe 'avis' do
          let!(:avis) { create(:avis, dossier: dossier) }

          subject { super()[:avis] }

          it { expect(subject[0][:introduction]).to eq(avis.introduction) }
        end

        describe 'etablissement' do
          let(:field_list) {
            [
              :siret,
              :siege_social,
              :naf,
              :libelle_naf,
              :adresse,
              :numero_voie,
              :type_voie,
              :nom_voie,
              :complement_adresse,
              :code_postal,
              :localite,
              :code_insee_localite,
            ]
          }
          subject { super()[:etablissement] }

          it do
            expect(subject[:siret]).to eq('44011762001530')
            expect(subject[:siege_social]).to eq(true)
            expect(subject[:naf]).to eq('4950Z')
            expect(subject[:libelle_naf]).to eq('Transports par conduites')
            expect(subject[:adresse]).to eq("GRTGAZ\r IMMEUBLE BORA\r 6 RUE RAOUL NORDLING\r 92270 BOIS COLOMBES\r")
            expect(subject[:numero_voie]).to eq('6')
            expect(subject[:type_voie]).to eq('RUE')
            expect(subject[:nom_voie]).to eq('RAOUL NORDLING')
            expect(subject[:complement_adresse]).to eq('IMMEUBLE BORA')
            expect(subject[:code_postal]).to eq('92270')
            expect(subject[:localite]).to eq('BOIS COLOMBES')
            expect(subject[:code_insee_localite]).to eq('92009')
            expect(subject.keys).to match_array(field_list)
          end
        end
      end
    end
  end
end
