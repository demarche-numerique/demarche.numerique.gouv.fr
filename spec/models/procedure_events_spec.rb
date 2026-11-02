# frozen_string_literal: true

describe 'Procedure events', type: :model do
  let(:event_store) { Events.store }
  let(:procedure) { procedures.individual }
  let(:administrateur) { administrateurs.default }

  def events_of(procedure)
    event_store.read.stream(Events.procedure_stream(procedure.id)).to_a
  end

  describe '#publish_event' do
    before { stub_const('Events::Probe', Class.new(Events::ProcedureEvent)) }

    it 'appends to the démarche stream with the actor in metadata' do
      procedure.publish_event(Events::Probe, author: administrateur, revision_id: 12)

      expect(event_store).to have_published(
        an_event(Events::Probe)
          .with_data(procedure_id: procedure.id, revision_id: 12)
          .with_metadata(actor: { type: 'Administrateur', id: administrateur.id })
      ).in_stream(Events.procedure_stream(procedure.id))
    end
  end

  describe 'demarche_publiee and demarche_republiee' do
    let(:draft_procedure) { create(:procedure, administrateurs: [administrateur], zones: [zones.default]) }

    it 'records the first publication, then a new revision, a close and a reopening' do
      draft_procedure.publish_or_reopen!(administrateur, 'demarche-evenements')
      first_revision_id = draft_procedure.published_revision_id

      draft_procedure.draft_revision.add_type_de_champ(type_champ: 'text', libelle: 'Nouveau champ')
      draft_procedure.publish_revision!(administrateur)
      second_revision_id = draft_procedure.published_revision_id

      draft_procedure.close!
      draft_procedure.publish_or_reopen!(administrateur, 'demarche-evenements')

      expect(event_store).to have_published(
        an_event(Events::DemarchePubliee).with_data(revision_id: first_revision_id).with_metadata(actor: { type: 'Administrateur', id: administrateur.id }),
        an_event(Events::DemarcheRepubliee).with_data(revision_id: second_revision_id),
        an_event(Events::DemarcheRepubliee).with_data(revision_id: second_revision_id)
      ).in_stream(Events.procedure_stream(draft_procedure.id))
      expect(events_of(draft_procedure).map(&:class).tally).to include(Events::DemarchePubliee => 1, Events::DemarcheRepubliee => 2)
    end

    it 'records a new revision published through publish_or_reopen! once' do
      procedure.draft_revision.add_type_de_champ(type_champ: 'text', libelle: 'Nouveau champ')

      expect { procedure.publish_or_reopen!(administrateur, procedure.path) }
        .to change { events_of(procedure).size }.by(1)
      expect(events_of(procedure).last).to be_an_instance_of(Events::DemarcheRepubliee)
    end
  end

  describe 'demarche_close and demarche_depubliee' do
    it 'records a close by an administrateur, and an automatic one without actor' do
      procedure.close!(administrateur)
      expect(event_store).to have_published(
        an_event(Events::DemarcheClose).with_metadata(actor: { type: 'Administrateur', id: administrateur.id })
      ).in_stream(Events.procedure_stream(procedure.id))

      procedure.publish_or_reopen!(administrateur, procedure.path)
      procedure.close!
      expect(events_of(procedure).last).to be_an_instance_of(Events::DemarcheClose)
      expect(events_of(procedure).last.metadata.to_h).not_to have_key(:actor)
    end

    it 'records the depublication of the démarche another one takes the path of' do
      other_procedure = create(:procedure, administrateurs: [administrateur], zones: [zones.default])

      other_procedure.publish_or_reopen!(administrateur, procedure.path)

      expect(event_store).to have_published(
        an_event(Events::DemarcheDepubliee).with_metadata(actor: { type: 'Administrateur', id: administrateur.id })
      ).in_stream(Events.procedure_stream(procedure.id))
      expect(procedure.reload).to be_depubliee
    end
  end

  describe 'demarche_supprimee and demarche_restauree' do
    it 'records both, the dossier events of each correlated to it' do
      dossier = dossiers.en_construction

      procedure.discard_and_keep_track!(administrateur)
      removal = events_of(procedure).reverse.find { it.is_a?(Events::DemarcheSupprimee) }
      expect(removal.metadata[:actor]).to eq(type: 'Administrateur', id: administrateur.id)
      dossier_removal = event_store.read.stream(Events.dossier_stream(dossier.id)).to_a.last
      expect(dossier_removal).to be_an_instance_of(Events::DossierSupprimeParAdministration)
      expect(dossier_removal.correlation_id).to eq(removal.event_id)
      expect(dossier_removal.causation_id).to eq(removal.event_id)

      procedure.restore(administrateur)
      restore = events_of(procedure).reverse.find { it.is_a?(Events::DemarcheRestauree) }
      dossier_restore = event_store.read.stream(Events.dossier_stream(dossier.id)).to_a.last
      expect(dossier_restore).to be_an_instance_of(Events::DossierRestaureParAdministration)
      expect(dossier_restore.correlation_id).to eq(restore.event_id)
    end
  end

  describe 'duree_conservation_modifiee' do
    it 'records the change, raised or lowered, by the administrateur of the request' do
      before = procedure.duree_conservation_dossiers_dans_ds

      Current.set(user: administrateur.user) do
        procedure.update!(duree_conservation_dossiers_dans_ds: before - 1)
      end

      expect(event_store).to have_published(
        an_event(Events::DureeConservationModifiee)
          .with_data(before:, after: before - 1)
          .with_metadata(actor: { type: 'Administrateur', id: administrateur.id })
      ).in_stream(Events.procedure_stream(procedure.id))
    end

    it 'records no actor outside the request of an administrateur' do
      before = procedure.duree_conservation_dossiers_dans_ds

      procedure.update!(duree_conservation_dossiers_dans_ds: before + 1)

      expect(events_of(procedure).last).to be_an_instance_of(Events::DureeConservationModifiee)
      expect(events_of(procedure).last.metadata.to_h).not_to have_key(:actor)
    end

    it 'records nothing when the retention is untouched' do
      expect { procedure.update!(libelle: 'Autre libellé') }.not_to change { events_of(procedure).size }
    end
  end
end
