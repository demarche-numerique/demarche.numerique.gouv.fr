# frozen_string_literal: true

describe API::V1::ProceduresController, type: :controller do
  let!(:admin) { create(:administrateur, :with_api_token) }
  let!(:token) { APIToken.generate(admin)[1] }

  it { expect(described_class).to be < APIController }

  describe 'GET show' do
    subject { get :show, params: { id: procedure_id, token: token } }

    context 'when procedure does not exist' do
      let(:procedure_id) { 999_999_999 }

      it { is_expected.to have_http_status(404) }
    end

    context 'when procedure belongs to administrateur without token' do
      let(:procedure_id) { create(:procedure).id }

      it { is_expected.to have_http_status(404) }
    end

    context 'when procedure exist but bad token' do
      let(:token) { 'bad' }
      let(:procedure_id) { create(:procedure, administrateur: admin).id }

      it { is_expected.to have_http_status(401) }
    end

    context 'when procedure exist' do
      let(:procedure_id) { create(:procedure, administrateur: admin).id }

      it { is_expected.to have_http_status(200) }

      describe 'body' do
        let(:procedure) { create(:procedure, :with_type_de_champ, :with_service, administrateur: admin) }
        let(:response) { get :show, params: { id: procedure.id, token: token } }

        subject { JSON.parse(response.body, symbolize_names: true)[:procedure] }

        it do
          expect(subject[:id]).to eq(procedure.id)
          expect(subject[:label]).to eq(procedure.libelle)
          expect(subject[:description]).to eq(procedure.description)
          expect(subject[:organisation]).to eq(procedure.organisation)
          expect(subject[:archived_at]).to eq(procedure.closed_at)
          expect(subject[:direction]).to eq("")
          expect(subject[:total_dossier]).to eq(procedure.total_dossier)
          is_expected.to have_key(:types_de_champ)
          expect(subject[:types_de_champ]).to be_an(Array)
        end

        describe 'type_de_champ' do
          subject { super()[:types_de_champ][0] }

          let(:champ) { procedure.active_revision.root_public_types_de_champ.first }

          it do
            expect(subject[:id]).to eq(champ.id)
            expect(subject[:libelle]).to eq(champ.libelle)
            expect(subject[:type_champ]).to eq(champ.type_champ)
            expect(subject[:description]).to eq(champ.description)
          end
        end

        describe 'service' do
          subject { super()[:service] }

          let(:service) { procedure.service }

          it do
            expect(subject[:id]).to eq(service.id)
            expect(subject[:email]).to eq(service.email)
            expect(subject[:name]).to eq(service.nom)
            expect(subject[:type_organization]).to eq(service.type_organisme)
            expect(subject[:organization]).to eq(service.organisme)
            expect(subject[:phone]).to eq(service.telephone)
            expect(subject[:schedule]).to eq(service.horaires)
            expect(subject[:address]).to eq(service.adresse)
          end
        end
      end
    end
  end
end
