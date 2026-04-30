# frozen_string_literal: true

describe Champs::PieceJustificativeController, type: :controller do
  let(:user) { create(:user) }
  let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }], types_de_champ_private: [{ type: :piece_justificative }]) }
  let(:dossier) { create(:dossier, user: user, procedure: procedure) }
  let(:champ) { dossier.project_champs_public.first }

  describe 'ensure_legitimate_access' do
    let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :text }]) }
    let(:dossier) { create(:dossier, user: user, procedure: procedure) }
    let(:champ) { dossier.project_champs_public.first }

    before { sign_in user }

    it 'returns not found when the champ is not a piece_justificative' do
      put :update, params: { dossier_id: champ.dossier_id, stable_id: champ.stable_id }, format: :turbo_stream
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'dossier state guard' do
    before { sign_in user }

    context 'when the dossier is en_instruction' do
      let(:dossier) { create(:dossier, :en_instruction, user: user, procedure: procedure) }
      let(:champ) { dossier.project_champs_public.first }

      it 'returns not found' do
        put :update, params: { dossier_id: champ.dossier_id, stable_id: champ.stable_id }, format: :turbo_stream
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the dossier is accepte' do
      let(:dossier) { create(:dossier, :accepte, user: user, procedure: procedure) }
      let(:champ) { dossier.project_champs_public.first }

      it 'returns not found' do
        put :update, params: { dossier_id: champ.dossier_id, stable_id: champ.stable_id }, format: :turbo_stream
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'private champ scope restriction' do
    before { sign_in user }

    context 'when a non-instructeur user tries to access a private champ' do
      let(:dossier) { create(:dossier, user: user, procedure: procedure) }
      let(:champ) { dossier.project_champs_private.first }

      it 'returns not found' do
        put :update, params: { dossier_id: champ.dossier_id, stable_id: champ.stable_id }, format: :turbo_stream
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe '#update' do
    render_views
    before { sign_in user }

    subject do
      put :update, params: {
        dossier_id: champ.dossier_id,
        stable_id: champ.stable_id,
        blob_signed_id: file,
      }.compact, format: :turbo_stream
    end

    context 'when the file is valid and then champ use external_data' do
      let(:file) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }

      before do
        allow_any_instance_of(Champs::PieceJustificativeChamp).to receive(:has_async_external_data?).and_return(true)
        expect_any_instance_of(Champs::PieceJustificativeChamp).to receive(:fetch_later!)
      end

      it 'attach the file' do
        subject
        champ.reload
        expect(champ.piece_justificative_file.attached?).to be true
        expect(champ.piece_justificative_file[0].filename).to eq('piece_justificative_0.pdf')
      end

      it 'renders the attachment template as Javascript' do
        subject
        expect(response.status).to eq(200)
        expect(response.body).to include("<turbo-stream action=\"replace\" target=\"#{champ.input_group_id}\">")
      end

      it 'updates dossier.last_champ_updated_at' do
        expect { subject }.to change { dossier.reload.last_champ_updated_at }
      end
    end

    context 'when the champ uses external_data but is already fetched with another file' do
      let(:file) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }

      before do
        allow_any_instance_of(Champs::PieceJustificativeChamp).to receive(:has_async_external_data?).and_return(true)
        champ.update_column(:external_state, :fetched)
      end

      it 'does not call fetch_later!' do
        expect_any_instance_of(Champs::PieceJustificativeChamp).not_to receive(:fetch_later!)
        subject
        expect(response.status).to eq(200)
      end
    end

    context 'when the champ is private and the dossier is not brouillon' do
      let(:file) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }
      let(:instructeur) { create(:instructeur) }
      let!(:dossier) { create(:dossier, :en_construction, user: user, procedure: procedure) }
      let!(:champ) { dossier.project_champs_private.first }

      before do
        instructeur.assign_to_procedure(procedure)
        sign_in instructeur.user
      end

      it 'updates dossier.last_champ_private_updated_at' do
        expect { subject }.to change { dossier.reload.last_champ_private_updated_at }
      end
    end

    context 'when the champ is public and the dossier is en_construction' do
      let(:file) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }
      let!(:dossier) { create(:dossier, :en_construction, user: user, procedure: procedure) }
      let!(:champ) { dossier.project_champs_public.first }

      it 'renders the footer with submit button' do
        subject
        expect(response.body).to include('Déposer les modifications')
      end
    end

    context 'when the file is invalid' do
      let(:file) { fixture_file_upload('spec/fixtures/files/invalid_file_format.json', 'bad/bad') }

      it 'doesn’t attach the file' do
        subject
        expect(champ.reload.piece_justificative_file.attached?).to be false
      end

      it 'renders an error' do
        subject
        expect(response.status).to eq(422)
        expect(response.header['Content-Type']).to include('application/json')
        expect(response.parsed_body).to eq({ 'errors' => ['Le champ « Piece justificative file » n’est pas d’un type accepté (bad/bad).'] })
      end
    end
  end

  describe '#template' do
    before { freeze_time }

    subject do
      get :template, params: {
        dossier_id: champ.dossier_id,
        stable_id: champ.stable_id,
      }
    end

    context "user signed in" do
      before { sign_in user }

      it 'redirects to the template' do
        subject
        expect(response).to redirect_to(rails_blob_url(champ.type_de_champ.piece_justificative_template.blob, disposition: 'attachment'))
      end
    end

    context "another user signed in" do
      before { sign_in create(:user) }

      it "should not share template url" do
        expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "user anonymous" do
      it 'does not redirect to the template' do
        subject
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
