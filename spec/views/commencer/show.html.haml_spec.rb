# frozen_string_literal: true

RSpec.describe 'commencer/show', type: :view do
  include Rails.application.routes.url_helpers

  let(:stored_query_params) { false }
  let(:procedure) { procedures.individual }
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

    xit 'renders ProConnect login button' do
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

  context 'when the procedure requires FranceConnect+' do
    before do
      allow(FranceConnectService).to receive(:enabled?).and_return(true)
      allow(FranceConnectPlusService).to receive(:enabled?).and_return(true)
      procedure.france_connect_plus_required = true
    end

    context 'and no user is signed in' do
      it 'offers FranceConnect+ only' do
        subject
        expect(rendered).to have_link('S’identifier avec FranceConnect', href: commencer_france_connect_plus_path(path: procedure.path), class: 'fr-connect--plus')
        expect(rendered).not_to have_link(href: commencer_france_connect_path(path: procedure.path))
        expect(rendered).not_to have_link('Créer un compte')
        expect(rendered).not_to have_link('J’ai déjà un compte')
      end

      context 'with FranceConnect+ switched off' do
        before { allow(FranceConnectPlusService).to receive(:enabled?).and_return(false) }

        it 'stays closed and says why' do
          subject
          expect(rendered).to have_text('FranceConnect+ est momentanément indisponible.')
          expect(rendered).not_to have_link(href: commencer_france_connect_path(path: procedure.path))
          expect(rendered).not_to have_link('Créer un compte')
        end
      end
    end

    context 'and the user signed in another way' do
      let(:user) { create :user }

      before { Current.user_session = instance_double(UserSession, via_france_connect_plus?: false) }

      it 'asks to sign in again with FranceConnect+' do
        subject
        expect(rendered).to have_link('S’identifier avec FranceConnect', href: commencer_france_connect_plus_path(path: procedure.path))
        expect(rendered).not_to have_link('Commencer un dossier')
      end
    end

    context 'and the user signed in another way opens the draft revision' do
      let(:user) { create :user }

      before do
        assign(:revision, procedure.draft_revision)
        Current.user_session = instance_double(UserSession, via_france_connect_plus?: false)
      end

      it 'asks to sign in again with FranceConnect+ on a published procedure' do
        subject
        expect(rendered).not_to have_link('Commencer un dossier')
      end

      context 'of a procedure not published yet' do
        let(:procedure) { create(:procedure, :for_individual) }

        it 'lets them start a test dossier' do
          subject
          expect(rendered).to have_link('Commencer un dossier', href: new_dossier_url(procedure_id: procedure.id, brouillon: true))
        end
      end
    end

    context 'and the user signed in with FranceConnect+' do
      let(:user) { create :user }

      before { Current.user_session = instance_double(UserSession, via_france_connect_plus?: true) }

      it 'lets them start a dossier' do
        subject
        expect(rendered).to have_link('Commencer un dossier', href: new_dossier_url(procedure_id: procedure.id))
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
      it_behaves_like 'it renders a link to create a new dossier', 'Commencer un dossier'
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
