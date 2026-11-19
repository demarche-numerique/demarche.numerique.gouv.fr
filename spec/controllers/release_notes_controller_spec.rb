# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReleaseNotesController, type: :controller do
  let!(:note_admin) { create(:release_note, categories: ['administrateur'], body: "Pour l’admin", released_on: Date.new(2023, 10, 15)) }
  let!(:note_instructeur) { create(:release_note, categories: ['instructeur'], body: "Pour l’instructeur", released_on: Date.new(2023, 10, 13)) }

  let(:user) { nil }
  let(:admin) { create(:user, administrateur: build(:administrateur)) }
  let(:instructeur) { create(:user, instructeur: build(:instructeur)) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe 'GET index' do
    subject { get :index }

    describe 'filtering' do
      before { subject }
      context 'user is admininistrateur' do
        let(:user) { admin }
        it do
          is_expected.to have_http_status(:ok)
          expect(assigns(:announces)).to eq([note_admin])
        end
      end

      context 'user is instructeur' do
        let(:user) { instructeur }
        it do
          is_expected.to have_http_status(:ok)
          expect(assigns(:announces)).to eq([note_instructeur])
        end
      end

      context 'user is expert' do
        let(:user) { create(:user, expert: build(:expert)) }
        it { expect(assigns(:announces)).to eq([]) }
      end
    end

    describe 'touch user announces_seen_at' do
      let(:user) { create(:user, administrateur: build(:administrateur)) }

      context 'when default categories' do
        it 'touch announces_seen_at' do
          expect { subject }.to change { user.reload.announces_seen_at }
        end

        context 'when current announces_seen_at is more recent than last announce' do
          before { user.update(announces_seen_at: 1.second.ago) }

          it 'does not touch announces_seen_at' do
            expect { subject }.not_to change { user.reload.announces_seen_at }
          end
        end
      end

      context 'when specific categories' do
        subject { get :index, params: { categories: ['administrateur', 'instructeur'] } }

        it 'does not touch announces_seen_at' do
          expect { subject }.not_to change { user.reload.announces_seen_at }
        end
      end
    end

    describe 'links rendering in release notes' do
      let(:user) { admin }
      let!(:note_admin) { create(:release_note, categories: ['administrateur'], body: 'Un lien vers <a href="https://example.gouv.fr">example.gouv.fr</a>', released_on: Date.new(2023, 10, 15)) }

      render_views
      before do
        get :index
      end

      it 'renders links with proper rel and target attributes' do
        expect(response.body).to include('href="https://example.gouv.fr"')
        expect(response.body).to include('rel="noreferrer noopener"')
        expect(response.body).to include('target="_blank"')
        expect(response.body).to include('title=')
      end

      context 'when a link href is malformed' do
        let!(:note_admin) { create(:release_note, categories: ['administrateur'], body: 'Écrivez-nous : <a href="mailto:contact">contact</a>', released_on: Date.new(2023, 10, 15)) }

        it 'still renders the page' do
          expect(response).to have_http_status(:ok)
          expect(response.body).to include('title="contact — Nouvel onglet"')
        end
      end
    end

    describe 'pagination rendering' do
      let(:user) { admin }

      render_views

      before do
        6.times { create(:release_note, categories: ['administrateur'], released_on: Date.new(2023, 9, 1) + it.days) }
      end

      it 'lazy loads the next page in a turbo frame' do
        get :index

        expect(response.body).to include('<turbo-frame loading="lazy" id="announces-page-2"')
        expect(response.body).to have_link('Annonces précédentes')
      end

      it 'renders the requested page in its own turbo frame' do
        get :index, params: { page: 2 }

        expect(response).to render_template('scrollable_list')
        expect(response.body).to include('<turbo-frame id="announces-page-2">')
        expect(response.body).to include('Sample release note body')
        expect(response.body).not_to include('Pour l’admin')
      end
    end
  end
end
