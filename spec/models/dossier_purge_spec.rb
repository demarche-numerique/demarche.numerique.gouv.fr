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

    context 'batching order' do
      let(:dossier) { create(:dossier) }

      it 'destroys champs in batches of 50 before destroying the dossier' do
        expect(dossier.champ_data).to receive(:in_batches).with(hash_including(of: 50)).at_least(:once).and_call_original
        dossier.purge_discarded
      end
    end

    context 'with multiple champs spanning several in_batches' do
      let(:procedure) { create(:procedure_with_dossiers, :published) }
      let(:dossier) { procedure.dossiers.first }

      before do
        51.times do |i|
          type_de_champ = create(:type_de_champ_text, procedure:, libelle: "Test #{i}")
          dossier.champ_data << type_de_champ.build_champ(value: "value #{i}")
        end
        dossier.save!
      end

      it 'destroys all champs even when count exceeds in_batches size' do
        expect(dossier.champ_data.count).to be > 50
        dossier.purge_discarded
        expect(ChampData.where(dossier_id: dossier.id)).to be_empty
      end
    end

    context 'when destroy raises after champs batching' do
      let(:procedure) { create(:procedure_with_dossiers, :published) }
      let(:dossier) { procedure.dossiers.first }
      let(:type_de_champ) { create(:type_de_champ_text, procedure:, libelle: 'Test') }
      let!(:champ) { dossier.champ_data.create!(type_de_champ:, value: 'kept') }

      before do
        allow(dossier).to receive(:destroy).and_raise(StandardError, 'boom')
        allow(Sentry).to receive(:capture_exception)
      end

      it 'rolls back the transaction so no champ is destroyed' do
        dossier.purge_discarded
        expect(ChampData.where(id: champ.id)).to exist
      end

      it 'does not enqueue ActiveStorage::PurgeJob (after_destroy_commit gated by commit)' do
        expect { dossier.purge_discarded }
          .not_to have_enqueued_job(ActiveStorage::PurgeJob)
      end

      it 'does not propagate the exception so the upstream find_each loop continues' do
        expect { dossier.purge_discarded }.not_to raise_error
      end
    end
  end

  describe '#purge_without_notice' do
    let(:dossier) { create(:dossier) }

    it 'destroys the dossier and its champs without creating a DeletedDossier' do
      expect(DeletedDossier).not_to receive(:create_from_dossier)

      dossier.purge_without_notice

      expect { dossier.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'destroys champs in batches of 50 before destroying the dossier' do
      expect(dossier.champ_data).to receive(:in_batches).with(hash_including(of: 50)).at_least(:once).and_call_original
      dossier.purge_without_notice
    end

    context 'with multiple champs spanning several in_batches' do
      let(:procedure) { create(:procedure_with_dossiers, :published) }
      let(:dossier) { procedure.dossiers.first }

      before do
        51.times do |i|
          type_de_champ = create(:type_de_champ_text, procedure:, libelle: "Test #{i}")
          dossier.champ_data << type_de_champ.build_champ(value: "value #{i}")
        end
        dossier.save!
      end

      it 'destroys all champs even when count exceeds in_batches size' do
        expect(dossier.champ_data.count).to be > 50
        dossier.purge_without_notice
        expect(ChampData.where(dossier_id: dossier.id)).to be_empty
      end
    end

    context 'when destroy raises after champs batching' do
      let(:procedure) { create(:procedure_with_dossiers, :published) }
      let(:dossier) { procedure.dossiers.first }
      let(:type_de_champ) { create(:type_de_champ_text, procedure:, libelle: 'Test') }
      let!(:champ) { dossier.champ_data.create!(type_de_champ:, value: 'kept') }

      before do
        allow(dossier).to receive(:destroy).and_raise(StandardError, 'boom')
        allow(Sentry).to receive(:capture_exception)
      end

      it 'rolls back so no champ is destroyed and does not propagate the exception' do
        expect { dossier.purge_without_notice }.not_to raise_error
        expect(ChampData.where(id: champ.id)).to exist
      end
    end
  end
end
