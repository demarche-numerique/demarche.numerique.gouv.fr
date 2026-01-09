# frozen_string_literal: true

describe 'users/dossiers/show/header', type: :view do
  let(:dossier) { create(:dossier, :en_construction, procedure: create(:procedure)) }
  let(:user) { dossier.user }

  before do
    sign_in user
  end

  subject! { render 'users/dossiers/show/header', dossier: dossier }

  it 'affiche les informations du dossier' do
    expect(rendered).to have_text(dossier.procedure.libelle)
    expect(rendered).to have_text("Dossier n° #{dossier.id}")
    expect(rendered).to have_text("en construction")

    expect(rendered).to have_selector("nav.fr-tabs")
    expect(rendered).to have_link("Suivi de votre dossier", href: dossier_path(dossier))
    expect(rendered).to have_link("Votre dossier", href: demande_dossier_path(dossier))
  end

  context "when the procedure is with accuse de lecture with a dossier en construction" do
    let(:procedure) { create(:procedure, :accuse_lecture) }
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }

    it "affiche les informations du dossier" do
      expect(rendered).to have_text("Dossier n° #{dossier.id}")
      expect(rendered).to have_text("en construction")
    end
  end

  context "when the procedure is with accuse de lecture with a dossier termine" do
    let(:procedure) { create(:procedure, :accuse_lecture) }
    let(:dossier) { create(:dossier, :accepte, procedure: procedure) }

    it "n’affiche pas les informations de décision" do
      expect(rendered).to have_text("Dossier n° #{dossier.id}")
      expect(rendered).to have_text("traité")
    end
  end

  context "when the procedure is closed with a dossier en construction" do
    let(:procedure) { create(:procedure, :closed) }
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }

    it "n’affiche pas de banner" do
      expect(rendered).not_to have_text("La démarche liée à votre dossier est close")
    end

    it 'can download the dossier' do
      expect(rendered).to have_text('Télécharger mon dossier')
    end
  end

  context "when the procedure is discarded with a dossier en construction" do
    let(:procedure) { create(:procedure, :with_service, :discarded) }
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }

    before do
      render 'users/dossiers/show/header', dossier: dossier
    end

    it 'affiche que la démarche est supprimée' do
      expect(rendered).to have_text("La démarche liée à votre dossier est supprimée")
      expect(rendered).to have_text("Vous pouvez toujours consulter votre dossier, mais il n’est plus possible de le modifier")
    end

    it 'can download the dossier' do
      expect(rendered).to have_text('Télécharger mon dossier')
    end

    it 'does not display a new procedure link' do
      expect(rendered).not_to have_text("Une nouvelle démarche est disponible, consultez-la ici")
    end
  end

  context "when the procedure is discarded with a dossier en construction and a replacement procedure" do
    let(:new_procedure) { create(:procedure, :with_service, aasm_state: :publiee) }
    let!(:procedure) { create(:procedure, :with_service, :discarded, replaced_by_procedure_id: new_procedure.id) }
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }

    before do
      render 'users/dossiers/show/header', dossier: dossier
    end

    it 'affiche que la démarche est supprimée' do
      expect(rendered).to have_text("La démarche liée à votre dossier est supprimée")
      expect(rendered).to have_text("Vous pouvez toujours consulter votre dossier, mais il n’est plus possible de le modifier")
    end

    it 'can download the dossier' do
      expect(rendered).to have_text('Télécharger mon dossier')
    end

    it 'displays a new procedure link' do
      expect(rendered).to have_text("Une nouvelle démarche est disponible, consultez-la ici")
    end

    it 'the has_many and belongs_to relations works well' do
      expect(procedure.replaced_by_procedure).to eq(new_procedure)
      expect(new_procedure.replaced_procedures).to eq([procedure])
    end
  end

  context "when the procedure is discarded with a dossier en construction and a replacement procedure is destroyed" do
    let(:new_procedure) { create(:procedure, :with_service, aasm_state: :publiee) }
    let!(:procedure) { create(:procedure, :with_service, :discarded, replaced_by_procedure_id: new_procedure.id) }
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }

    before do
      new_procedure.destroy!
    end

    it 'put the old procedure.replaced_by_procedure blank' do
      expect(procedure.replaced_by_procedure).to eq(nil)
    end
  end

  context "when the procedure is discarded with a dossier terminé" do
    let(:procedure) { create(:procedure, :with_service, :discarded) }
    let(:dossier) { create(:dossier, :accepte, procedure: procedure) }

    it 'affiche que la démarche est supprimée' do
      expect(rendered).to have_text("La démarche liée à votre dossier est supprimée")
      expect(rendered).to have_text("Votre dossier a été traité par l’administration, aucune action n’est possible")
    end

    it 'can download the dossier' do
      expect(rendered).to have_text('Télécharger mon dossier')
    end
  end

  context "when user is invited" do
    context "when the procedure is closed with a dossier en construction" do
      let(:procedure) { create(:procedure, :closed) }
      let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }
      let(:user) { create(:user) }

      before do
        create(:invite, user: user, dossier: dossier)
      end

      it "n’affiche pas de banner" do
        expect(rendered).not_to have_text("La démarche liée à votre dossier est close")
      end

      it 'can not download the dossier' do
        expect(rendered).not_to have_text('Télécharger mon dossier')
      end
    end
  end
end
