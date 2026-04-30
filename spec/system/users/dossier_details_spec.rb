# frozen_string_literal: true

require 'system/users/dossier_shared_examples.rb'

describe 'Dossier details:' do
  let(:user) { create(:user) }
  let(:procedure) { create(:simple_procedure) }
  let(:dossier) { create(:dossier, :en_construction, :with_individual, :with_commentaires, user: user, procedure: procedure) }

  before do
    visit_dossier dossier
  end

  scenario 'the user can see the summary of the dossier status' do
    expect(page).to have_current_path(dossier_path(dossier))
    expect(page).to have_content(dossier.id)
    expect(page).to have_selector('.status-explanation')
    expect(page).to have_text(dossier.commentaires.last.body)
  end

  scenario 'the user can download a deposit receipt' do
    visit dossier_path(dossier)
    expect(page).to have_link("Obtenir une attestation de dépôt de dossier", href: %r{dossiers/#{dossier.id}/attestation_depot.pdf})
  end

  describe "the user can see the mean time they are expected to wait" do
    context "when the dossier is in construction" do
      it "displays the estimated wait duration" do
        allow_any_instance_of(Procedure).to receive(:stats_usual_traitement_time).and_return([1.day, 1.day, 1.day])
        visit dossier_path(dossier)
        expect(page).to have_text("Dans le meilleur des cas, le délai d’instruction est : 1 jour")
      end
    end

    context "when the dossier is in instruction" do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, :with_commentaires, user: user, procedure: procedure) }

      it "displays the estimated wait duration" do
        allow_any_instance_of(Procedure).to receive(:stats_usual_traitement_time).and_return([1.day, 1.day, 1.day])
        visit dossier_path(dossier)
        expect(page).to have_text("Dans le meilleur des cas, le délai d’instruction est : 1 jour")
      end
    end
  end

  scenario 'the user is redirected from old URLs' do
    visit "/users/dossiers/#{dossier.id}/recapitulatif"
    expect(page).to have_current_path(dossier_path(dossier))
  end

  context 'with js', js: true do
    it_behaves_like 'the user can edit the submitted demande'
    it_behaves_like 'the user can send messages to the instructeur'
  end

  private

  def visit_dossier(dossier)
    visit dossier_path(dossier)

    expect(page).to have_current_path(new_user_session_path)
    fill_in 'user_email', with: user.email
    fill_in 'user_password', with: user.password
    click_on 'Se connecter'

    expect(page).to have_current_path(dossier_path(dossier))
  end
end
