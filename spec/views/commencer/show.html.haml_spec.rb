# frozen_string_literal: true

RSpec.describe 'commencer/show', type: :view do
  include Rails.application.routes.url_helpers

  let(:stored_query_params) { false }
  let(:procedure) { create(:procedure, :published, :for_individual, :with_service) }
  let(:dossiers) { drafts + not_drafts }
  let(:drafts) { [] }
  let(:not_drafts) { [] }
  let(:preview_dossiers) { dossiers.take(3) }
  let(:user) { nil }

  before do
    allow(view).to receive(:current_administrateur).and_return(user&.administrateur)
  end

  before do
    assign(:procedure, procedure)
    assign(:revision, procedure.active_revision)
    assign(:dossiers, dossiers)
    assign(:drafts, drafts)
    assign(:not_drafts, not_drafts)
    assign(:preview_dossiers, preview_dossiers)
    if user
      sign_in user
    end

    allow(view).to receive(:stored_query_params?).and_return(stored_query_params)
  end

  subject { render }

  context 'when no user is signed in' do
    before do
      allow(FranceConnectService).to receive(:enabled?).and_return(true)
      allow(ProConnectService).to receive(:enabled?).and_return(true)
    end

    it 'renders sign-in and sign-up links' do
      subject
      expect(rendered).to have_link('Créer un compte')
      expect(rendered).to have_link('J’ai déjà un compte')
      expect(rendered).to have_link('S’identifier avec FranceConnect')
    end

    it 'renders ProConnect login button' do
      subject
      expect(rendered).to have_css('.pro-connect-login')
    end

    context 'when ProConnect is disabled' do
      before do
        allow(FranceConnectService).to receive(:enabled?).and_return(true)
        allow(ProConnectService).to receive(:enabled?).and_return(false)
      end

      it 'does not render ProConnect login button' do
        subject
        expect(rendered).not_to have_css('.pro-connect-login')
      end
    end
  end

  context 'when the user is already signed in' do
    let(:user) { create :user }

    shared_examples_for 'it renders a link to create a new dossier' do |button_label|
      it 'renders a link to create a new dossier' do
        subject
        expect(rendered).to have_link(button_label, href: new_dossier_url(procedure_id: procedure.id))
      end
    end

    context 'and they don’t have any dossier on this procedure' do
      it_behaves_like 'it renders a link to create a new dossier', 'Commencer la démarche'
    end

    context 'and they have a pending draft' do
      let!(:drafts) { [create(:dossier, user: user, procedure: procedure)] }

      it_behaves_like 'it renders a link to create a new dossier', 'Commencer un nouveau dossier'

      it 'renders a link to resume the pending draft' do
        subject
        expect(rendered).to have_text(time_ago_in_words(drafts.first.created_at))
        expect(rendered).to have_link('Continuer à remplir mon dossier', href: brouillon_dossier_path(drafts.first))
      end
    end

    context 'and they have a submitted dossier' do
      let!(:drafts) { [create(:dossier, user: user, procedure: procedure)] }
      let!(:not_drafts) { [create(:dossier, :en_construction, :with_individual, user: user, procedure: procedure)] }

      it_behaves_like 'it renders a link to create a new dossier', 'Commencer un nouveau dossier'

      it 'renders a link to the submitted dossier' do
        subject
        expect(rendered).to have_text(time_ago_in_words(not_drafts.first.depose_at))
        expect(rendered).to have_link('Voir mon dossier', href: dossier_path(not_drafts.first))
      end
    end

    context 'and they have several submitted dossiers' do
      let!(:drafts) { [create(:dossier, user: user, procedure: procedure)] }
      let!(:not_drafts) { create_list(:dossier, 2, :en_construction, :with_individual, user: user, procedure: procedure) }

      it_behaves_like 'it renders a link to create a new dossier', 'Commencer un nouveau dossier'

      it 'renders a link to the dossiers list' do
        subject
        expect(rendered).to have_link('Voir mes dossiers en cours', href: dossiers_path(procedure_id: procedure.id))
      end
    end

    context 'and they have a prefilled dossier' do
      let!(:prefilled_dossier) { create(:dossier, :prefilled, user: user, procedure: procedure) }

      before { assign(:prefilled_dossier, prefilled_dossier) }

      it 'renders a link to resume the prefilled dossier' do
        subject
        expect(rendered).to have_text(time_ago_in_words(prefilled_dossier.created_at))
        expect(rendered).to have_link('Poursuivre mon dossier prérempli', href: brouillon_dossier_path(prefilled_dossier))
      end
    end
  end

  context "procedure is draft" do
    let(:procedure) { create(:procedure, :draft) }
    let(:user) { create :user }

    it 'renders a warning' do
      subject
      expect(rendered).to have_text("Cette démarche est actuellement en test")
    end

    context "when user is admin" do
      let(:user) { procedure.administrateurs.first.user }

      it "renders warning about draft" do
        subject
        expect(rendered).to have_text("Cette démarche est actuellement en test")
        expect(rendered).to have_text("Ne communiquez pas ce lien")
      end
    end
  end

  context "revision is draft" do
    before {
      assign(:revision, procedure.draft_revision)
    }

    it "renders warning about draft" do
      subject
      expect(rendered).to have_text("Démarche en test")
    end
  end
end
