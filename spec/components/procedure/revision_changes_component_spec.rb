# frozen_string_literal: true

describe Procedure::RevisionChangesComponent, type: :component do
  describe 'dossier_link changes' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :dossier_link, libelle: 'Dossier lié' }]) }
    let(:new_revision) { procedure.create_new_revision }
    let(:tdc) { procedure.active_revision.public_root_type_de_champs.first }

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

  describe "carte layers changes" do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :carte, libelle: 'La carte' }]) }
    let(:new_revision) { procedure.create_new_revision }
    let(:tdc) { procedure.active_revision.public_root_type_de_champs.first }

    subject do
      render_inline(described_class.new(new_revision: new_revision.reload, previous_revision: procedure.active_revision))
      page
    end

    # `cadastres` excluded: it is mutually exclusive with `rpg`
    let(:known_layers) { TypesDeChamp::Carte.option_keys }
    let(:enabled_layers) { known_layers - [:cadastres] }

    before do
      updated_tdc = new_revision.find_and_ensure_exclusive_use(tdc.stable_id)
      updated_tdc.update!(options: enabled_layers.index_with { true })
    end

    it "displays every added layer with its translated label" do
      expect(subject).to have_text("Les référentiels cartographiques du champ")
      expect(subject).not_to have_css(".translation_missing")

      enabled_layers.each do |layer|
        expect(subject).to have_text(I18n.t(layer, scope: [:administrateurs, :carte_layers]))
      end
    end

    it "has a translation for every known layer" do
      known_layers.each do |layer|
        expect(I18n.exists?("administrateurs.carte_layers.#{layer}")).to be(true), "missing translation for carte layer #{layer}"
      end
    end
  end

  describe "repetition limits changes" do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :repetition, libelle: "Bloc" }]) }
    let(:new_revision) { procedure.create_new_revision }
    let(:tdc) { procedure.active_revision.public_root_type_de_champs.first }

    subject do
      render_inline(described_class.new(new_revision: new_revision.reload, previous_revision: procedure.active_revision))
      page
    end

    context "when min_repetitions changes to a positive value" do
      before do
        tdc.update!(limit_repetitions: "1", min_repetitions: "2")
        procedure.active_revision.reload
        updated_tdc = new_revision.find_and_ensure_exclusive_use(tdc.stable_id)
        updated_tdc.update!(min_repetitions: "3")
      end

      it "displays the update message with the new value" do
        expect(subject).to have_text("Le minimum est désormais 3.")
      end
    end

    context "when min_repetitions changes to 0 (valid for non-mandatory block)" do
      before do
        tdc.update!(limit_repetitions: "1", min_repetitions: "2")
        procedure.active_revision.reload
        updated_tdc = new_revision.find_and_ensure_exclusive_use(tdc.stable_id)
        updated_tdc.update!(min_repetitions: "0")
      end

      it "displays the update message with 0, not a removal message" do
        expect(subject).to have_text("Le minimum est désormais 0.")
        expect(subject).not_to have_text("a été supprimé")
      end
    end

    context "when min_repetitions is removed (set to nil)" do
      before do
        tdc.update!(limit_repetitions: "1", min_repetitions: "2")
        procedure.active_revision.reload
        updated_tdc = new_revision.find_and_ensure_exclusive_use(tdc.stable_id)
        updated_tdc.update!(min_repetitions: nil)
      end

      it "displays the removal message" do
        expect(subject).to have_text("a été supprimé")
        expect(subject).not_to have_text("désormais")
      end
    end
  end
end
