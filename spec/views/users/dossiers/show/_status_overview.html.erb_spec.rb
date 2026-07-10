# frozen_string_literal: true

describe 'users/dossiers/show/_status_overview', type: :view do
  before do
    allow(view).to receive(:current_administrateur).and_return(nil)
    allow(dossier.procedure).to receive(:usual_traitement_time_for_recent_dossiers).and_return([1.day, 2.days, 3.days])
  end

  subject! { render 'users/dossiers/show/status_overview', dossier: dossier }

  matcher :have_timeline_item do |selector|
    match do |rendered|
      expect(rendered).to have_selector(item_selector(selector))
    end

    chain :active do
      @active = true
    end

    chain :inactive do
      @active = false
    end

    def item_selector(selector)
      if @active
        "#{selector}[aria-current=true]"
      else
        "#{selector}:not([aria-current=true])"
      end
    end
  end

  context 'when en construction' do
    let(:dossier) { create :dossier, :en_construction }

    it 'renders the timeline (without the final states)' do
      expect(rendered).not_to have_timeline_item('.brouillon')
      expect(rendered).to have_timeline_item('.en-construction').active
      expect(rendered).to have_timeline_item('.en-instruction').inactive
      expect(rendered).to have_timeline_item('.termine').inactive
    end

    it 'works' do
      subject
      expect(subject).to have_selector('.status-explanation .en-construction')
      expect(subject).to have_text("Selon nos estimations")
      expect(subject).to have_text(/le délai d.instruction est de 1 jour/)
      expect(subject).to have_text(/Pour les dossiers demandant quelques échanges, le délai d.instruction est d.environ 2 jours/)
      expect(subject).to have_text(/dossier est incomplet.*le délai d.instruction est d.environ 3 jours/)
    end

    context 'with a pending correction' do
      let(:dossier) do
        create(:dossier, :en_construction).tap { create(:dossier_correction, dossier: it) }
      end

      it 'renders the "à corriger" notice (warning, not an alert)' do
        expect(rendered).to have_selector('.fr-notice.fr-notice--warning')
        expect(rendered).not_to have_selector('.fr-alert')
        expect(rendered).to have_text('Consultez les corrections à apporter à votre dossier')
        expect(rendered).to have_link(href: messagerie_dossier_path(dossier))
      end
    end

    context 'with a pending response' do
      let(:dossier) do
        create(:dossier, :en_construction).tap { create(:dossier_pending_response, dossier: it) }
      end

      it 'renders the "en attente de réponse" notice (warning, not an alert)' do
        expect(rendered).to have_selector('.fr-notice.fr-notice--warning')
        expect(rendered).not_to have_selector('.fr-alert')
        expect(rendered).to have_text("répondez à l'administration")
        expect(rendered).to have_link(href: messagerie_dossier_path(dossier))
      end
    end
  end

  context 'when en construction on a brouillon procedure (EN TEST) without estimation' do
    let(:dossier) { create :dossier, :en_construction, procedure: create(:procedure) }
    subject { nil }

    before do
      allow(dossier.procedure).to receive(:stats_usual_traitement_time).and_return(nil)
      allow(dossier.procedure).to receive(:usual_traitement_time_for_recent_dossiers).and_return(nil)
    end

    context 'as a regular usager (non-admin)' do
      it 'does not show delay estimation placeholders' do
        render 'users/dossiers/show/status_overview', dossier: dossier
        expect(rendered).not_to have_text("[indication du délai]")
        expect(rendered).not_to have_text("Selon nos estimations")
      end
    end

    context 'as an administrateur of the procedure' do
      before { allow(view).to receive(:current_administrateur).and_return(dossier.procedure.administrateurs.first) }

      it 'shows delay estimation with placeholders' do
        render 'users/dossiers/show/status_overview', dossier: dossier
        expect(rendered).to have_text("[indication du délai]")
        expect(rendered).to have_text("[indication du délai moyen]")
      end
    end
  end

  context 'when en instruction' do
    let(:dossier) { create :dossier, :en_instruction }

    it 'renders the timeline (without the final states)' do
      expect(rendered).not_to have_timeline_item('.brouillon')
      expect(rendered).to have_timeline_item('.en-construction').inactive
      expect(rendered).to have_timeline_item('.en-instruction').active
      expect(rendered).to have_timeline_item('.termine').inactive
    end

    it 'works' do
      expect(subject).to have_selector('.status-explanation .en-instruction')
      expect(subject).to have_text("Selon nos estimations")
      expect(subject).to have_text(/le délai d.instruction est de 1 jour/)
      expect(subject).to have_text(/Pour les dossiers demandant quelques échanges, le délai d.instruction est d.environ 2 jours/)
      expect(subject).to have_text(/dossier est incomplet.*le délai d.instruction est d.environ 3 jours/)
    end
  end

  context 'when accepté' do
    let(:dossier) { create :dossier, :accepte, :with_motivation }

    it 'works' do
      expect(subject).not_to have_selector('.status-timeline')
      expect(subject).to have_selector('.status-explanation .accepte')
      expect(subject).to have_text(dossier.motivation)
      expect(subject).to have_link('https://demarche.numerique.gouv.fr', href: 'https://demarche.numerique.gouv.fr')
    end

    context 'with attestation' do
      let(:dossier) { create :dossier, :accepte, :with_attestation_acceptation }
      it { is_expected.to have_link(nil, href: attestation_dossier_path(dossier)) }
    end
  end

  context 'when refusé' do
    let(:dossier) { create :dossier, :refuse, :with_motivation }

    it 'works' do
      expect(subject).not_to have_selector('.status-timeline')
      expect(subject).to have_selector('.status-explanation .refuse')
      expect(subject).to have_text(dossier.motivation)
      expect(subject).to have_link(nil, href: messagerie_dossier_url(dossier, anchor: 'new_commentaire'))
      expect(subject).to have_link('https://prefecture-93.fr/faq', href: 'https://prefecture-93.fr/faq')
    end

    context 'with attestation' do
      let(:dossier) { create :dossier, :refuse, :with_attestation_refus }

      it do
        is_expected.to have_link(nil, href: attestation_dossier_path(dossier))
      end
    end
  end

  context 'when classé sans suite' do
    let(:dossier) { create :dossier, :sans_suite, :with_motivation }

    it 'works' do
      expect(subject).not_to have_selector('.status-timeline')
      expect(subject).to have_selector('.status-explanation .sans-suite')
      expect(subject).to have_text(dossier.motivation)
      expect(subject).to have_link('https://ddt-93.fr', href: 'https://ddt-93.fr')
    end
  end

  context 'when terminé but the procedure has an accuse de lecture' do
    let(:dossier) { create(:dossier, :sans_suite, :with_motivation, procedure: create(:procedure, :accuse_lecture)) }

    it 'works' do
      expect(subject).not_to have_selector('.status-explanation .sans-suite')
      expect(subject).not_to have_text(dossier.motivation)
      expect(subject).to have_text('Cette démarche est soumise à un accusé de lecture.')
    end
  end
end
