# frozen_string_literal: true

describe 'administrateurs/procedures/show', type: :view do
  let(:closed_at) { nil }
  let(:procedure) { create(:procedure, :with_service, closed_at: closed_at, public_type_de_champs: [{ type: :yes_no }]) }

  before do
    assign(:procedure, procedure)
    assign(:procedure_lien, commencer_url(path: procedure.path))
    assign(:procedure_lien_test, commencer_test_url(path: procedure.path))
    allow(view).to receive(:current_administrateur).and_return(procedure.administrateurs.first)
  end

  describe 'procedure is draft' do
    context 'when procedure have a instructeur affected' do
      before do
        create(:instructeur).assign_to_procedure(procedure)
        render
      end

      it "renders content" do
        expect(rendered).to have_css('#publish-procedure-link')
        expect(rendered).not_to have_css('#close-procedure-link')
        expect(rendered).to have_content('En test')
        expect(rendered).not_to have_css('#archive-procedure')
        expect(rendered).to have_css('#delete-procedure')
        expect(rendered).to have_css('#clone-procedure')
        expect(rendered).to have_css('#preview-procedure')
      end
    end
  end

  describe 'procedure is published' do
    before do
      procedure.publish!(procedure.administrateurs.first)
      procedure.reload
      render
    end

    it "renders content" do
      expect(rendered).not_to have_css('#publish-procedure-link')
      expect(rendered).to have_css('#close-procedure-link')
      expect(rendered).to have_css('#archive-procedure')
      expect(rendered).not_to have_css('#delete-procedure')
      expect(rendered).to have_css('#clone-procedure')
      expect(rendered).to have_css('#preview-procedure')
    end
  end

  describe 'procedure is closed' do
    before do
      procedure.publish!(procedure.administrateurs.first)
      procedure.close!
      procedure.reload
      render
    end

    it "renders content" do
      expect(rendered).not_to have_css('#close-procedure-link')
      expect(rendered).to have_css('#publish-procedure-link')
      expect(rendered).to have_content('Réactiver')
      expect(rendered).to have_css('#delete-procedure')
      expect(rendered).to have_css('#clone-procedure')
      expect(rendered).to have_css('#preview-procedure')
    end
  end

  describe 'procedure is closed with a notification to the applicants' do
    before do
      procedure.publish!(procedure.administrateurs.first)
      procedure.close!
      procedure.update_columns(closing_notification_en_cours: true, closed_at: Time.zone.local(2026, 12, 1, 14, 5))
    end

    it 'dates the notification in French' do
      render

      expect(rendered).to have_content('Un email a été envoyé pour informer les usagers le 01 décembre 2026')
    end

    it 'dates the notification in English' do
      I18n.with_locale(:en) { render }

      expect(rendered).to have_content('Applicants were notified by email on 01 December 2026')
    end
  end

  describe 'procedure is closed with internal_procedure replacement' do
    let(:replacement) { create(:procedure, :published, libelle: 'Démarche de remplacement') }

    before do
      procedure.publish!(procedure.administrateurs.first)
      procedure.update!(closing_reason: 'internal_procedure', replaced_by_procedure_id: replacement.id)
      procedure.close!
      procedure.reload
    end

    context 'when the replacement procedure is kept' do
      before { render }

      it 'renders the libelle and a link to the replacement procedure' do
        expect(rendered).to have_content('Cette démarche est remplacée par une autre démarche')
        expect(rendered).to have_link('Démarche de remplacement', href: admin_procedure_path(replacement))
      end
    end

    context 'when the replacement procedure is discarded' do
      before do
        replacement.discard!
        render
      end

      it 'renders the libelle without a link and a fallback message' do
        expect(rendered).to have_content('Démarche de remplacement')
        expect(rendered).to have_content("n’est plus disponible")
        expect(rendered).not_to have_link('Démarche de remplacement')
      end
    end

    context 'when the replaced_by_procedure_id points to a missing procedure' do
      before do
        procedure.update_column(:replaced_by_procedure_id, Procedure.maximum(:id).to_i + 1_000)
        render
      end

      it 'renders a fallback message and does not crash' do
        expect(rendered).to have_content("Cette démarche était remplacée par une démarche qui n’est plus disponible.")
        expect(rendered).not_to have_content('Cette démarche est remplacée par une autre démarche')
      end
    end
  end
end
