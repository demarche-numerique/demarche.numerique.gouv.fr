# frozen_string_literal: true

describe Procedure::RevisionChangesComponent, type: :component do
  describe 'dossier_link changes' do
    let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :dossier_link, libelle: 'Dossier lié' }]) }
    let(:new_revision) { procedure.create_new_revision }
    let(:tdc) { procedure.active_revision.types_de_champ_public.first }

    subject do
      render_inline(described_class.new(new_revision: new_revision.reload, previous_revision: procedure.active_revision))
      page
    end

    context 'when procedures_limit is enabled' do
      before do
        updated_tdc = new_revision.find_and_ensure_exclusive_use(tdc.stable_id)
        updated_tdc.update!(procedures_limit: "1")
      end

      it 'displays the activation message' do
        expect(subject).to have_text("Limiter à certaines démarches")
        expect(subject).to have_text("activée")
        expect(subject).to have_text("Dossier lié")
      end
    end

    context 'when procedures_limit is disabled' do
      before do
        tdc.update!(procedures_limit: "1")
        procedure.active_revision.reload

        updated_tdc = new_revision.find_and_ensure_exclusive_use(tdc.stable_id)
        updated_tdc.update!(procedures_limit: "0")
      end

      it 'displays the deactivation message' do
        expect(subject).to have_text("Limiter à certaines démarches")
        expect(subject).to have_text("désactivée")
        expect(subject).to have_text("Dossier lié")
      end
    end

    context 'when dossier_link_procedure_ids are added' do
      let!(:proc_a) { create(:procedure, libelle: "Démarche A") }
      let!(:proc_b) { create(:procedure, libelle: "Démarche B") }

      before do
        updated_tdc = new_revision.find_and_ensure_exclusive_use(tdc.stable_id)
        updated_tdc.update!(dossier_link_procedure_ids: [proc_a.id, proc_b.id])
      end

      it 'displays the added procedures with id and libelle' do
        expect(subject).to have_text("Les démarches autorisées pour le champ")
        expect(subject).to have_text("N° #{proc_a.id} - Démarche A")
        expect(subject).to have_text("N° #{proc_b.id} - Démarche B")
      end
    end

    context 'when dossier_link_procedure_ids are removed' do
      let!(:proc_a) { create(:procedure, libelle: "Démarche A") }
      let!(:proc_b) { create(:procedure, libelle: "Démarche B") }
      let!(:proc_c) { create(:procedure, libelle: "Démarche C") }

      before do
        tdc.update!(dossier_link_procedure_ids: [proc_a.id, proc_b.id, proc_c.id])
        procedure.active_revision.reload

        updated_tdc = new_revision.find_and_ensure_exclusive_use(tdc.stable_id)
        updated_tdc.update!(dossier_link_procedure_ids: [proc_a.id])
      end

      it 'displays the removed procedures with id and libelle' do
        expect(subject).to have_text("supprimés")
        expect(subject).to have_text("N° #{proc_b.id} - Démarche B")
        expect(subject).to have_text("N° #{proc_c.id} - Démarche C")
        expect(subject).not_to have_text("N° #{proc_a.id} - Démarche A")
      end
    end
  end
end
