# frozen_string_literal: true

describe Dossier, type: :model do
  describe '#purge_discarded' do
    let(:dossier) { create(:dossier) }

    it 'creates a deleted dossier, purge the dols and then destroy' do
      expect(DeletedDossier).to receive(:create_from_dossier)
      expect(dossier.dossier_operation_logs).to receive(:purge_discarded)
      expect(dossier).to receive(:destroy)

      dossier.purge_discarded
    end

    context 'with multiple champs spanning several in_batches' do
      let(:procedure) { create(:procedure_with_dossiers, :published) }
      let(:dossier) { procedure.dossiers.first }

      before do
        51.times do |i|
          type_de_champ = create(:type_de_champ_text, procedure:, libelle: "Test #{i}")
          dossier.champs << type_de_champ.build_champ(value: "value #{i}")
        end
        dossier.save!
      end

      it 'destroys all champs even when count exceeds in_batches size' do
        expect(dossier.champs.count).to be > 50
        dossier.purge_discarded
        expect(Champ.where(dossier_id: dossier.id)).to be_empty
      end
    end

    context 'when destroy raises after champs batching' do
      let(:procedure) { create(:procedure_with_dossiers, :published) }
      let(:dossier) { procedure.dossiers.first }
      let(:type_de_champ) { create(:type_de_champ_text, procedure:, libelle: 'Test') }
      let!(:champ) { dossier.champs.create!(type_de_champ:, value: 'kept') }

      before do
        allow(dossier).to receive(:destroy).and_raise(StandardError, 'boom')
        allow(Sentry).to receive(:capture_exception)
      end

      it 'rolls back the transaction so no champ is destroyed' do
        dossier.purge_discarded
        expect(Champ.where(id: champ.id)).to exist
      end

      it 'does not enqueue ActiveStorage::PurgeJob (after_destroy_commit gated by commit)' do
        expect { dossier.purge_discarded }
          .not_to have_enqueued_job(ActiveStorage::PurgeJob)
      end

      it 'does not propagate the exception so the upstream find_each loop continues' do
        expect { dossier.purge_discarded }.not_to raise_error
      end
    end

    context 'batching order' do
      let(:dossier) { create(:dossier) }

      it 'destroys champs in batches of 50 before destroying the dossier' do
        expect(dossier.champs).to receive(:in_batches).with(hash_including(of: 50)).at_least(:once).and_call_original
        dossier.purge_discarded
      end
    end
  end
end
