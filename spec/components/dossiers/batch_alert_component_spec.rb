# frozen_string_literal: true

RSpec.describe Dossiers::BatchAlertComponent, type: :component do
  let(:instructeur) { create(:instructeur) }
  let(:procedure) { create(:procedure) }

  subject { render_inline(component).to_html }
  let(:component) do
    described_class.new(
      batch: batch_operation,
      procedure:
    )
  end
  before do
    allow(component).to receive(:procedure_path).and_return(Rails.application.routes.url_helpers.instructeur_procedure_path(procedure, statut: 'a-suivre'))
  end

  describe 'archiver' do
    let(:component) do
      described_class.new(
        batch: batch_operation,
        procedure: procedure
      )
    end
    let!(:dossier) { create(:dossier, :accepte, procedure: procedure) }
    let!(:dossier_2) { create(:dossier, :accepte, procedure: procedure) }
    let!(:batch_operation) { create(:batch_operation, operation: :archiver, dossiers: [dossier, dossier_2], instructeur: instructeur) }
    context 'in_progress' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--info')
        is_expected.to have_text("Une action de masse est en cours")
        is_expected.to have_text("1/2 dossiers sont en cours de déplacement dans « à archiver »")
        is_expected.to have_text("Cette opération a été lancée par #{instructeur.email}, il y a moins d’une minute")
      end
    end

    context 'finished and success' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.track_processed_dossier(true, dossier_2)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--success')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("2 dossiers ont été placés dans « à archiver »")
        expect(batch_operation.seen_at).to eq(nil)
      end
    end

    context 'finished and fail' do
      before {
        batch_operation.track_processed_dossier(false, dossier)
        batch_operation.track_processed_dossier(true, dossier_2)
        batch_operation.reload
      }

      it do
        is_expected.to have_selector('.fr-alert--warning')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("1/2 dossiers ont été placés dans « à archiver »")
        expect(batch_operation.seen_at).to eq(nil)
      end

      it 'on next render "seen_at" is set to avoid rendering alert' do
        render_inline(described_class.new(batch: batch_operation, procedure:)).to_html
        expect(batch_operation.seen_at).not_to eq(nil)
      end
    end
  end

  describe 'desarchiver' do
    let(:component) do
      described_class.new(
        batch: batch_operation,
        procedure: procedure
      )
    end
    let!(:dossier) { create(:dossier, :accepte, procedure: procedure) }
    let!(:dossier_2) { create(:dossier, :accepte, procedure: procedure) }
    let!(:batch_operation) { create(:batch_operation, operation: :desarchiver, dossiers: [dossier, dossier_2], instructeur: instructeur) }
    context 'in_progress' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--info')
        is_expected.to have_text("Une action de masse est en cours")
        is_expected.to have_text("1/2 dossiers sont en cours de retrait de « à archiver »")
        is_expected.to have_text("Cette opération a été lancée par #{instructeur.email}, il y a moins d’une minute")
      end
    end

    context 'finished and success' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.track_processed_dossier(true, dossier_2)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--success')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("2 dossiers ont été retirés de « à archiver »")
        expect(batch_operation.seen_at).to eq(nil)
      end
    end

    context 'finished and fail' do
      before {
        batch_operation.track_processed_dossier(false, dossier)
        batch_operation.track_processed_dossier(true, dossier_2)
        batch_operation.reload
      }

      it do
        is_expected.to have_selector('.fr-alert--warning')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("1/2 dossiers ont été retirés de « à archiver »")
        expect(batch_operation.seen_at).to eq(nil)
      end

      it 'on next render "seen_at" is set to avoid rendering alert' do
        render_inline(described_class.new(batch: batch_operation, procedure:)).to_html
        expect(batch_operation.seen_at).not_to eq(nil)
      end
    end
  end

  describe 'passer_en_instruction' do
    let(:component) do
      described_class.new(
        batch: batch_operation,
        procedure: procedure
      )
    end
    let!(:dossier) { create(:dossier, :en_construction, procedure: procedure) }
    let!(:dossier_2) { create(:dossier, :en_construction, procedure: procedure) }
    let!(:batch_operation) { create(:batch_operation, operation: :passer_en_instruction, dossiers: [dossier, dossier_2], instructeur: instructeur) }

    context 'in_progress' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--info')
        is_expected.to have_text("Une action de masse est en cours")
        is_expected.to have_text("1/2 dossiers ont été passés en instruction")
      end
    end

    context 'finished and success' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.track_processed_dossier(true, dossier_2)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--success')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("2 dossiers ont été passés en instruction")
        expect(batch_operation.seen_at).to eq(nil)
      end
    end

    context 'finished and fail' do
      before {
        batch_operation.track_processed_dossier(false, dossier)
        batch_operation.track_processed_dossier(true, dossier_2)
        batch_operation.reload
      }

      it do
        is_expected.to have_selector('.fr-alert--warning')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("1/2 dossiers ont été passés en instruction")
        expect(batch_operation.seen_at).to eq(nil)
      end

      it 'on next render "seen_at" is set to avoid rendering alert' do
        render_inline(described_class.new(batch: batch_operation, procedure:)).to_html
        expect(batch_operation.seen_at).not_to eq(nil)
      end
    end
  end

  describe 'repousser_expiration' do
    let(:component) do
      described_class.new(
        batch: batch_operation,
        procedure: procedure
      )
    end
    let!(:dossier) { create(:dossier, :accepte, procedure: procedure) }
    let!(:dossier_2) { create(:dossier, :accepte, procedure: procedure) }
    let!(:batch_operation) { create(:batch_operation, operation: :repousser_expiration, dossiers: [dossier, dossier_2], instructeur: instructeur) }
    context 'in_progress' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--info')
        is_expected.to have_text("Une action de masse est en cours")
        is_expected.to have_text("1/2 dossiers seront conservé 1 mois supplémentaire")
        is_expected.to have_text("Cette opération a été lancée par #{instructeur.email}, il y a moins d’une minute")
      end
    end

    context 'finished and success' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.track_processed_dossier(true, dossier_2)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--success')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("2 dossiers seront conservé 1 mois supplémentaire")
        expect(batch_operation.seen_at).to eq(nil)
      end
    end

    context 'finished and fail' do
      before {
        batch_operation.track_processed_dossier(false, dossier)
        batch_operation.track_processed_dossier(true, dossier_2)
        batch_operation.reload
      }

      it do
        is_expected.to have_selector('.fr-alert--warning')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("1/2 dossiers seront conservé 1 mois supplémentaire")
        expect(batch_operation.seen_at).to eq(nil)
      end

      it 'on next render "seen_at" is set to avoid rendering alert' do
        render_inline(described_class.new(batch: batch_operation, procedure:)).to_html
        expect(batch_operation.seen_at).not_to eq(nil)
      end
    end
  end

  describe 'accepter' do
    let(:component) do
      described_class.new(
        batch: batch_operation,
        procedure: procedure
      )
    end
    let!(:dossier) { create(:dossier, :en_instruction, procedure: procedure) }
    let!(:dossier_2) { create(:dossier, :en_instruction, procedure: procedure) }
    let!(:batch_operation) { create(:batch_operation, operation: :accepter, dossiers: [dossier, dossier_2], instructeur: instructeur) }

    context 'in_progress' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--info')
        is_expected.to have_text("Une action de masse est en cours")
        is_expected.to have_text("1/2 dossiers ont été acceptés")
      end
    end

    context 'finished and success' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.track_processed_dossier(true, dossier_2)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--success')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("2 dossiers ont été acceptés")
        expect(batch_operation.seen_at).to eq(nil)
      end
    end

    context 'finished and fail' do
      before {
        batch_operation.track_processed_dossier(false, dossier)
        batch_operation.track_processed_dossier(true, dossier_2)
        batch_operation.reload
      }

      it do
        is_expected.to have_selector('.fr-alert--warning')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("1/2 dossiers ont été acceptés")
        expect(batch_operation.seen_at).to eq(nil)
      end

      it 'on next render "seen_at" is set to avoid rendering alert' do
        render_inline(described_class.new(batch: batch_operation, procedure:)).to_html
        expect(batch_operation.seen_at).not_to eq(nil)
      end
    end
  end

  describe 'refuser' do
    let(:component) do
      described_class.new(
        batch: batch_operation,
        procedure: procedure
      )
    end
    let!(:dossier) { create(:dossier, :en_instruction, procedure: procedure) }
    let!(:dossier_2) { create(:dossier, :en_instruction, procedure: procedure) }
    let!(:batch_operation) { create(:batch_operation, operation: :refuser, dossiers: [dossier, dossier_2], instructeur: instructeur) }

    context 'in_progress' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--info')
        is_expected.to have_text("Une action de masse est en cours")
        is_expected.to have_text("1/2 dossiers ont été refusés")
      end
    end

    context 'finished and success' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.track_processed_dossier(true, dossier_2)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--success')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("2 dossiers ont été refusés")
        expect(batch_operation.seen_at).to eq(nil)
      end
    end
  end

  describe 'classer_sans_suite' do
    let(:component) do
      described_class.new(
        batch: batch_operation,
        procedure: procedure
      )
    end
    let!(:dossier) { create(:dossier, :en_instruction, procedure: procedure) }
    let!(:dossier_2) { create(:dossier, :en_instruction, procedure: procedure) }
    let!(:batch_operation) { create(:batch_operation, operation: :classer_sans_suite, dossiers: [dossier, dossier_2], instructeur: instructeur) }

    context 'in_progress' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--info')
        is_expected.to have_text("Une action de masse est en cours")
        is_expected.to have_text("1/2 dossiers ont été classés sans suite")
      end
    end

    context 'finished and success' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.track_processed_dossier(true, dossier_2)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--success')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("2 dossiers ont été classés sans suite")
        expect(batch_operation.seen_at).to eq(nil)
      end
    end
  end

  describe 'follow' do
    let(:component) do
      described_class.new(
        batch: batch_operation,
        procedure: procedure
      )
    end
    let!(:dossier) { create(:dossier, :en_construction, procedure: procedure) }
    let!(:dossier_2) { create(:dossier, :en_instruction, procedure: procedure) }
    let!(:batch_operation) { create(:batch_operation, operation: :follow, dossiers: [dossier, dossier_2], instructeur: instructeur) }

    context 'in_progress' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--info')
        is_expected.to have_text("Une action de masse est en cours")
        is_expected.to have_text("1/2 dossiers ont été suivis")
      end
    end

    context 'finished and success' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.track_processed_dossier(true, dossier_2)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--success')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("2 dossiers ont été suivis")
        expect(batch_operation.seen_at).to eq(nil)
      end
    end

    context 'finished and fail' do
      before {
        batch_operation.track_processed_dossier(false, dossier)
        batch_operation.track_processed_dossier(true, dossier_2)
        batch_operation.reload
      }

      it do
        is_expected.to have_selector('.fr-alert--warning')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("1/2 dossiers ont été suivis")
        expect(batch_operation.seen_at).to eq(nil)
      end

      it 'on next render "seen_at" is set to avoid rendering alert' do
        render_inline(described_class.new(batch: batch_operation, procedure:)).to_html
        expect(batch_operation.seen_at).not_to eq(nil)
      end
    end
  end

  describe 'unfollow' do
    let(:component) do
      described_class.new(
        batch: batch_operation,
        procedure: procedure
      )
    end
    let!(:dossier) { create(:dossier, :en_construction, :followed, procedure: procedure) }
    let!(:dossier_2) { create(:dossier, :en_instruction, :followed, procedure: procedure) }
    let!(:batch_operation) { create(:batch_operation, operation: :unfollow, dossiers: [dossier, dossier_2], instructeur: instructeur) }

    context 'in_progress' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--info')
        is_expected.to have_text("Une action de masse est en cours")
        is_expected.to have_text("1/2 dossiers ne sont plus suivis")
      end
    end

    context 'finished and success' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.track_processed_dossier(true, dossier_2)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--success')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("2 dossiers ne sont plus suivis")
        expect(batch_operation.seen_at).to eq(nil)
      end
    end

    context 'finished and fail' do
      before {
        batch_operation.track_processed_dossier(false, dossier)
        batch_operation.track_processed_dossier(true, dossier_2)
        batch_operation.reload
      }

      it do
        is_expected.to have_selector('.fr-alert--warning')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("1/2 dossiers ne sont plus suivis")
        expect(batch_operation.seen_at).to eq(nil)
      end

      it 'on next render "seen_at" is set to avoid rendering alert' do
        render_inline(described_class.new(batch: batch_operation, procedure:)).to_html
        expect(batch_operation.seen_at).not_to eq(nil)
      end
    end
  end

  describe 'create avis' do
    let(:component) do
      described_class.new(
        batch: batch_operation,
        procedure: procedure
      )
    end
    let!(:dossier) { create(:dossier, :en_construction, procedure: procedure) }
    let!(:dossier_2) { create(:dossier, :en_instruction, procedure: procedure) }
    let!(:batch_operation) { create(:batch_operation, operation: :create_avis, dossiers: [dossier, dossier_2], instructeur: instructeur) }

    context 'in_progress' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--info')
        is_expected.to have_text("Une action de masse est en cours")
        is_expected.to have_text("Des demandes d’avis sont en cours d’envoi pour 1/2 dossier")
      end
    end

    context 'finished and success' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.track_processed_dossier(true, dossier_2)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--success')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("Des demandes d’avis ont été envoyées pour 2/2 dossiers")
        expect(batch_operation.seen_at).to eq(nil)
      end
    end

    context 'finished and fail' do
      before {
        batch_operation.track_processed_dossier(false, dossier)
        batch_operation.track_processed_dossier(true, dossier_2)
        batch_operation.reload
      }

      it do
        is_expected.to have_selector('.fr-alert--warning')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("Des demandes d’avis ont été envoyées pour 1/2 dossier")
        expect(batch_operation.seen_at).to eq(nil)
      end

      it 'on next render "seen_at" is set to avoid rendering alert' do
        render_inline(described_class.new(batch: batch_operation, procedure:)).to_html
        expect(batch_operation.seen_at).not_to eq(nil)
      end
    end
  end

  describe 'create commentaire' do
    let(:component) do
      described_class.new(
        batch: batch_operation,
        procedure: procedure
      )
    end
    let!(:dossier) { create(:dossier, :en_construction, procedure: procedure) }
    let!(:dossier_2) { create(:dossier, :brouillon, procedure: procedure) }
    let!(:batch_operation) { create(:batch_operation, operation: :create_commentaire, dossiers: [dossier, dossier_2], instructeur: instructeur) }

    context 'in_progress' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--info')
        is_expected.to have_text("Une action de masse est en cours")
        is_expected.to have_text("Un message est en cours d’envoi pour 1/2 dossiers")
      end
    end

    context 'finished and success' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.track_processed_dossier(true, dossier_2)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--success')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("Un message a été envoyé pour 2/2 dossiers")
        expect(batch_operation.seen_at).to eq(nil)
      end
    end

    context 'finished and fail' do
      before {
        batch_operation.track_processed_dossier(false, dossier)
        batch_operation.track_processed_dossier(true, dossier_2)
        batch_operation.reload
      }

      it do
        is_expected.to have_selector('.fr-alert--warning')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("Un message a été envoyé pour 1/2 dossiers")
        expect(batch_operation.seen_at).to eq(nil)
      end

      it 'on next render "seen_at" is set to avoid rendering alert' do
        render_inline(described_class.new(batch: batch_operation, procedure:)).to_html
        expect(batch_operation.seen_at).not_to eq(nil)
      end
    end
  end

  describe 'restaurer' do
    let(:component) do
      described_class.new(
        batch: batch_operation,
        procedure: procedure
      )
    end
    let!(:dossier) { create(:dossier, :accepte, procedure: procedure, hidden_by_administration_at: Time.zone.now) }
    let!(:dossier_2) { create(:dossier, :accepte, procedure: procedure, hidden_by_administration_at: Time.zone.now) }
    let!(:batch_operation) { create(:batch_operation, operation: :restaurer, dossiers: [dossier, dossier_2], instructeur: instructeur) }

    context 'in_progress' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--info')
        is_expected.to have_text("Une action de masse est en cours")
        is_expected.to have_text("1/2 dossiers ont été restaurés")
      end
    end

    context 'finished and success' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.track_processed_dossier(true, dossier_2)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--success')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("2 dossiers ont été restaurés")
        expect(batch_operation.seen_at).to eq(nil)
      end
    end

    context 'finished and fail' do
      before {
        batch_operation.track_processed_dossier(false, dossier)
        batch_operation.track_processed_dossier(true, dossier_2)
        batch_operation.reload
      }

      it do
        is_expected.to have_selector('.fr-alert--warning')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("1/2 dossiers ont été restaurés")
        expect(batch_operation.seen_at).to eq(nil)
      end

      it 'on next render "seen_at" is set to avoid rendering alert' do
        render_inline(described_class.new(batch: batch_operation, procedure:)).to_html
        expect(batch_operation.seen_at).not_to eq(nil)
      end
    end
  end

  describe 'repasser en construction' do
    let(:component) do
      described_class.new(
        batch: batch_operation,
        procedure: procedure
      )
    end
    let!(:dossier) { create(:dossier, :en_instruction, procedure: procedure) }
    let!(:dossier_2) { create(:dossier, :en_instruction, procedure: procedure) }
    let!(:batch_operation) { create(:batch_operation, operation: :repasser_en_construction, dossiers: [dossier, dossier_2], instructeur: instructeur) }

    context 'in_progress' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--info')
        is_expected.to have_text("Une action de masse est en cours")
        is_expected.to have_text("1/2 dossiers ont été repassés en construction")
      end
    end

    context 'finished and success' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.track_processed_dossier(true, dossier_2)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--success')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("2 dossiers ont été repassés en construction")
        expect(batch_operation.seen_at).to eq(nil)
      end
    end

    context 'finished and fail' do
      before {
        batch_operation.track_processed_dossier(false, dossier)
        batch_operation.track_processed_dossier(true, dossier_2)
        batch_operation.reload
      }

      it do
        is_expected.to have_selector('.fr-alert--warning')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("1/2 dossiers ont été repassés en construction")
        expect(batch_operation.seen_at).to eq(nil)
      end

      it 'on next render "seen_at" is set to avoid rendering alert' do
        render_inline(described_class.new(batch: batch_operation, procedure:)).to_html
        expect(batch_operation.seen_at).not_to eq(nil)
      end
    end
  end

  describe 'supprimer' do
    let(:component) do
      described_class.new(
        batch: batch_operation,
        procedure: procedure
      )
    end
    let!(:dossier) { create(:dossier, :accepte, procedure: procedure) }
    let!(:dossier_2) { create(:dossier, :accepte, procedure: procedure) }
    let!(:batch_operation) { create(:batch_operation, operation: :supprimer, dossiers: [dossier, dossier_2], instructeur: instructeur) }

    context 'in_progress' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--info')
        is_expected.to have_text("Une action de masse est en cours")
        is_expected.to have_text("1/2 dossiers ont été placés à la corbeille")
      end
    end

    context 'finished and success' do
      before {
         batch_operation.track_processed_dossier(true, dossier)
         batch_operation.track_processed_dossier(true, dossier_2)
         batch_operation.reload
       }

      it do
        is_expected.to have_selector('.fr-alert--success')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("2 dossiers ont été placés à la corbeille")
        expect(batch_operation.seen_at).to eq(nil)
      end
    end

    context 'finished and fail' do
      before {
        batch_operation.track_processed_dossier(false, dossier)
        batch_operation.track_processed_dossier(true, dossier_2)
        batch_operation.reload
      }

      it do
        is_expected.to have_selector('.fr-alert--warning')
        is_expected.to have_text("L’action de masse est terminée")
        is_expected.to have_text("1/2 dossiers ont été placés à la corbeille")
        expect(batch_operation.seen_at).to eq(nil)
      end

      it 'on next render "seen_at" is set to avoid rendering alert' do
        render_inline(described_class.new(batch: batch_operation, procedure:)).to_html
        expect(batch_operation.seen_at).not_to eq(nil)
      end
    end
  end
end
