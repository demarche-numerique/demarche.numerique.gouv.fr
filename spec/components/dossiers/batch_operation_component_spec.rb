# frozen_string_literal: true

RSpec.describe Dossiers::BatchOperationComponent, type: :component do
  include ActionView::Context
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::FormOptionsHelper

  describe "available_operations" do
    let(:component) do
      cmp = nil
      form_for(BatchOperation.new, url: Rails.application.routes.url_helpers.instructeur_batch_operations_path(procedure_id: 1), method: :post, data: { controller: 'batch-operation' }) do |_form|
        cmp = described_class.new(statut: statut, procedure: procedure)
      end
      cmp
    end

    let(:user) { create(:user) }
    let(:procedure) { create(:procedure) }

    before do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    end

    subject { render_inline(component).to_html }

    context 'statut traite' do
      let(:statut) { 'traites' }
      it do
        is_expected.to have_button('Déplacer les dossiers dans “à archiver“', disabled: true)
        is_expected.to have_button('Mettre les dossiers à la corbeille', disabled: true)
        is_expected.to have_button('Envoyer un message aux usagers', disabled: true)
      end
    end

    context 'statut suivis' do
      let(:statut) { 'suivis' }

      it do
        is_expected.to have_button('Passer les dossiers en instruction', disabled: true)
        is_expected.to have_button('Rendre une décision', disabled: true)
        is_expected.to have_button('Autres actions multiples', disabled: true)
        is_expected.to have_button('Repasser les dossiers en construction', disabled: true)
        is_expected.to have_button('Ne plus suivre les dossiers', disabled: true)
        is_expected.to have_button('Demander un avis externe', disabled: true)
        is_expected.to have_button('Envoyer un message aux usagers', disabled: true)
      end

      it 'renders the instruction modal outside the batch form' do
        is_expected.to have_selector('#modal-instruction-button')
        is_expected.to have_selector('#modal-instruction-title', text: 'Rendre une décision sur les dossiers')
        is_expected.to have_text('Accepter les dossiers')
        is_expected.not_to have_selector('form #modal-instruction-button')
      end

      context 'with expert review disallowed procedure' do
        before {
          procedure.update!(allow_expert_review: false)
        }
        it do
          is_expected.to have_button('Passer les dossiers en instruction', disabled: true)
          is_expected.to have_button('Rendre une décision', disabled: true)
          is_expected.to have_button('Autres actions multiples', disabled: true)
          is_expected.to have_button('Repasser les dossiers en construction', disabled: true)
          is_expected.to have_button('Ne plus suivre les dossiers', disabled: true)
          is_expected.not_to have_button('Demander un avis externe', disabled: true)
        end
      end
    end

    context 'statut a-suivre' do
      let(:statut) { 'a-suivre' }
      it do
        is_expected.to have_button('Passer les dossiers en instruction', disabled: true)
        is_expected.to have_button('Suivre les dossiers', disabled: true)
        is_expected.to have_button('Envoyer un message aux usagers', disabled: true)
      end
    end

    context 'statut tous' do
      let(:statut) { 'tous' }
      it do
        is_expected.to have_button('Envoyer un message aux usagers', disabled: true)
        is_expected.to have_button('Rendre une décision', disabled: true)
        is_expected.to have_button('Autres actions multiples', disabled: true)
        is_expected.to have_button('Suivre les dossiers', disabled: true)
        is_expected.to have_button('Ne plus suivre les dossiers', disabled: true)
        is_expected.to have_button('Passer les dossiers en instruction', disabled: true)
        is_expected.to have_button('Repasser les dossiers en construction', disabled: true)
        is_expected.to have_button('Déplacer les dossiers dans “à archiver“', disabled: true)
        is_expected.to have_button('Mettre les dossiers à la corbeille', disabled: true)
        is_expected.to have_button('Demander un avis externe', disabled: true)
      end
    end

    context 'statut supprimes' do
      let(:statut) { 'supprimes' }
      it do
        is_expected.to have_button('Restaurer', disabled: true)
        is_expected.to have_button('Restaurer et conserver un mois de plus', disabled: true)
      end
    end
  end

  describe "operations_for_dossier" do
    let(:procedure) { create(:procedure) }
    let(:statut) { 'whatever' }
    let(:instructeur) { create(:instructeur) }

    subject { described_class.new(statut: statut, procedure: procedure).operations_for_dossier(dossier, instructeur) }

    context "when the dossier is en_construction" do
      let(:dossier) { create(:dossier, :en_construction) }

      it do
        expect(subject).to match_array(["passer_en_instruction", "repousser_expiration", "create_avis", "restaurer_repousser_expiration", "follow", "create_commentaire"])
      end
    end

    context "when the dossier is en_instruction" do
      let(:dossier) { create(:dossier, :en_instruction) }

      it do
        expect(subject).to match_array([
          "repasser_en_construction",
          "create_avis",
          "instruction",
          "follow",
          "create_commentaire",
        ])
      end
    end

    context "when the dossier is termine" do
      context "and visible by administration" do
        let(:dossier) { create(:dossier, :accepte) }

        it do
          expect(subject).to match_array(["archiver", "desarchiver", "supprimer", "repousser_expiration", "restaurer", "follow", "create_commentaire"])
        end
      end

      context "and hidden by administration" do
        let(:dossier) { create(:dossier, :accepte, hidden_by_administration_at: Time.zone.now) }

        it do
          expect(subject).to match_array(["archiver", "desarchiver", "supprimer", "repousser_expiration", "restaurer", "follow", "create_commentaire"])
        end
      end

      context "and hidden by expired" do
        let(:dossier) { create(:dossier, :accepte, hidden_by_expired_at: Time.zone.now) }

        it do
          expect(subject).to match_array(["archiver", "desarchiver", "supprimer", "repousser_expiration", "restaurer_repousser_expiration", "follow", "create_commentaire"])
        end
      end

      context "and followed by instructeur" do
        let(:dossier) { create(:dossier, :accepte) }

        before { instructeur.follow(dossier) }

        it do
          expect(subject).to match_array(["archiver", "desarchiver", "repousser_expiration", "restaurer", "supprimer", "unfollow", "create_commentaire"])
        end
      end
    end
  end
end
