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
    let(:known_layers) { TypesDeChamp::CarteTypeDeChamp.option_keys }
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

  describe "referentiel changes" do
    let(:referentiel) { create(:api_referentiel, :exact_match, hint: "avant") }
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :referentiel, libelle: "Le référentiel", referentiel: }]) }
    let(:new_revision) { procedure.create_new_revision }
    let(:tdc) { procedure.active_revision.public_root_type_de_champs.first }

    subject do
      render_inline(described_class.new(new_revision: new_revision.reload, previous_revision: procedure.active_revision))
      page
    end

    before do
      updated_tdc = new_revision.find_and_ensure_exclusive_use(tdc.stable_id)
      updated_tdc.update!(referentiel: create(:api_referentiel, :autocomplete, hint: "après"))
    end

    it "displays every changed referentiel field" do
      expect(subject).to have_text("La nouvelle URL est « https://tabular-api.data.gouv.fr?finess__contains={Valeur saisie par l'usager} »", normalize_ws: true)
      expect(subject).to have_text("Le nouveau mode est « autocomplete »", normalize_ws: true)
      expect(subject).to have_text("La nouvelle indication est « après »", normalize_ws: true)
      expect(subject).to have_text("Le nouvel exemple est « 0100026 »", normalize_ws: true)
    end
  end
  describe "private annotation changes" do
    let(:procedure) do
      create(:procedure, :published, private_type_de_champs: [
        { type: :integer_number, libelle: "Montant", range_number: "1", min_number: "1" },
        { type: :drop_down_list, libelle: "Avis", options: ["oui"] },
      ])
    end
    let(:new_revision) { procedure.create_new_revision }
    let(:tdcs) { procedure.active_revision.private_root_type_de_champs }

    subject do
      render_inline(described_class.new(new_revision: new_revision.reload, previous_revision: procedure.active_revision))
      page
    end

    before do
      new_revision.find_and_ensure_exclusive_use(tdcs[0].stable_id).update!(min_number: "2")
      new_revision.find_and_ensure_exclusive_use(tdcs[1].stable_id).update!(drop_down_mode: "advanced", referentiel: create(:csv_referentiel, :with_items))
    end

    it "displays every change with the annotation wording" do
      expect(subject).to have_text("La valeur minimale pour l’annotation privée « Montant » a été modifiée. Le minimum est désormais 2.", normalize_ws: true)
      expect(subject).to have_text("Le type de liste de choix de l’annotation privée « Avis » a été modifié.", normalize_ws: true)
      expect(subject).to have_text("Le référentiel de l’annotation privée « Avis » a été modifié.", normalize_ws: true)
      expect(subject).not_to have_css(".translation_missing")
    end
  end

  describe "header section, birthdate and pre rempli changes" do
    let(:procedure) do
      create(:procedure, :published, public_type_de_champs: [
        { type: :header_section, libelle: "Titre", level: "1" },
        { type: :date, libelle: "Naissance", birthdate: "0" },
        { type: :pre_rempli, libelle: "Prérempli" },
      ])
    end
    let(:new_revision) { procedure.create_new_revision }
    let(:tdcs) { procedure.active_revision.public_root_type_de_champs }

    subject do
      render_inline(described_class.new(new_revision: new_revision.reload, previous_revision: procedure.active_revision))
      page
    end

    before do
      new_revision.find_and_ensure_exclusive_use(tdcs[0].stable_id).update!(header_section_level: "2")
      new_revision.find_and_ensure_exclusive_use(tdcs[1].stable_id).update!(birthdate: "1", prefill_with_france_connect_information: "1")
      new_revision.find_and_ensure_exclusive_use(tdcs[2].stable_id).update!(pre_rempli_hidden: "1")
    end

    it "displays every change" do
      expect(subject).to have_text("Le niveau du titre de section « Titre » a été modifié. Le nouveau niveau est 2.", normalize_ws: true)
      expect(subject).to have_text("Le champ « Naissance » a été modifié. Il s’agit désormais d’une date de naissance.", normalize_ws: true)
      expect(subject).to have_text("Le champ « Naissance » a été modifié. La date est désormais préremplie avec FranceConnect.", normalize_ws: true)
      expect(subject).to have_text("Le champ « Prérempli » est désormais masqué pour l’usager.", normalize_ws: true)
    end
  end

  # ---------------------------------------------------------------------------
  # Regressions found while reviewing PR #13705.
  # Each example below is red on ba2b9d2962.
  # ---------------------------------------------------------------------------

  describe "options cleared by a before_save callback (nil, not '0')" do
    let(:new_revision) { procedure.create_new_revision }
    let(:tdc) { procedure.active_revision.public_root_type_de_champs.first }

    subject do
      render_inline(described_class.new(new_revision: new_revision.reload, previous_revision: procedure.active_revision))
      page
    end

    context "when unchecking birthdate clears the FranceConnect prefill" do
      let(:procedure) do
        create(:procedure, :published, public_type_de_champs: [
          { type: :date, libelle: "Naissance", birthdate: "1", prefill_with_france_connect_information: "1" },
        ])
      end

      before do
        new_revision.find_and_ensure_exclusive_use(tdc.stable_id).update!(birthdate: "0")
      end

      it "reports the FranceConnect prefill as removed" do
        expect(new_revision.reload.type_de_champs.first.prefill_with_france_connect_information).to be_nil

        expect(subject).to have_text("La date n’est plus préremplie avec FranceConnect.")
        expect(subject).not_to have_text("La date est désormais préremplie avec FranceConnect.")
      end
    end

    context "when checking birthdate clears date_in_past and range_date" do
      let(:procedure) do
        create(:procedure, :published, public_type_de_champs: [
          { type: :date, libelle: "Naissance", birthdate: "0", date_in_past: "1", range_date: "1" },
        ])
      end

      before do
        new_revision.find_and_ensure_exclusive_use(tdc.stable_id).update!(birthdate: "1")
      end

      it "reports both constraints as removed" do
        expect(subject).to have_text("Il s’agit désormais d’une date de naissance.")

        expect(subject).not_to have_text("La date doit être dans le passé")
        expect(subject).not_to have_text("La limite des valeurs a été activée.")
        expect(subject).to have_text("La date n’est plus limitée à une date dans le passé.")
        expect(subject).to have_text("La limite des valeurs a été désactivée.")
      end
    end
  end

  describe "piece justificative leaving a forced nature" do
    let(:procedure) do
      create(:procedure, :published, public_type_de_champs: [
        { type: :piece_justificative, libelle: "Justificatif", nature: "rib" },
      ])
    end
    let(:new_revision) { procedure.create_new_revision }
    let(:tdc) { procedure.active_revision.public_root_type_de_champs.first }

    subject do
      render_inline(described_class.new(new_revision: new_revision.reload, previous_revision: procedure.active_revision))
      page
    end

    before do
      new_revision.find_and_ensure_exclusive_use(tdc.stable_id).update!(nature: "non_specifie")
    end

    it "reports the nature change only" do
      expect(subject).to have_text("La nature de pièce justificative")

      expect(subject).not_to have_text("Les familles de formats acceptés")
    end
  end

  describe "legacy header section without an explicit level" do
    let(:procedure) do
      create(:procedure, :published, public_type_de_champs: [{ type: :header_section, libelle: "Titre" }])
    end
    let(:new_revision) { procedure.create_new_revision }
    let(:tdc) { procedure.active_revision.public_root_type_de_champs.first }

    subject do
      render_inline(described_class.new(new_revision: new_revision.reload, previous_revision: procedure.active_revision))
      page
    end

    before do
      tdc.update!(header_section_level: nil)
      procedure.active_revision.reload

      # what the editor re-submits for a legacy section (header_section_level_value is 1)
      new_revision.find_and_ensure_exclusive_use(tdc.stable_id).update!(header_section_level: "1")
    end

    it "does not report a level change when the level is semantically identical" do
      expect(subject).not_to have_text("Le niveau du titre de section")
    end
  end

  describe "explication collapsible explanation" do
    let(:procedure) do
      create(:procedure, :published, public_type_de_champs: [
        { type: :explication, libelle: "Explication", collapsible_explanation_enabled: "0", collapsible_explanation_text: "Un texte" },
      ])
    end
    let(:new_revision) { procedure.create_new_revision }
    let(:tdc) { procedure.active_revision.public_root_type_de_champs.first }

    subject do
      render_inline(described_class.new(new_revision: new_revision.reload, previous_revision: procedure.active_revision))
      page
    end

    before do
      new_revision.find_and_ensure_exclusive_use(tdc.stable_id).update!(collapsible_explanation_enabled: "1")
    end

    it "is translated" do
      expect(subject).not_to have_css(".translation_missing")
      expect(subject).to have_text("Le texte complémentaire affichable au clic du champ « Explication » a été ajouté.", normalize_ws: true)
    end
  end

  describe "formatted champ expression reguliere indications" do
    let(:procedure) do
      create(:procedure, :published, public_type_de_champs: [
        { type: :formatted, libelle: "Code", formatted_mode: "advanced", expression_reguliere: "\\d+", expression_reguliere_indications: "avant" },
      ])
    end
    let(:new_revision) { procedure.create_new_revision }
    let(:tdc) { procedure.active_revision.public_root_type_de_champs.first }

    subject do
      render_inline(described_class.new(new_revision: new_revision.reload, previous_revision: procedure.active_revision))
      page
    end

    before do
      new_revision.find_and_ensure_exclusive_use(tdc.stable_id).update!(expression_reguliere_indications: "après")
    end

    it "is translated" do
      expect(subject).not_to have_css(".translation_missing")
    end
  end

  describe "referentiel changes on a private annotation" do
    let(:referentiel) { create(:api_referentiel, :exact_match, hint: "avant") }
    let(:procedure) do
      create(:procedure, :published, private_type_de_champs: [{ type: :referentiel, libelle: "Le référentiel", referentiel: }])
    end
    let(:new_revision) { procedure.create_new_revision }
    let(:tdc) { procedure.active_revision.private_root_type_de_champs.first }

    subject do
      render_inline(described_class.new(new_revision: new_revision.reload, previous_revision: procedure.active_revision))
      page
    end

    before do
      new_revision.find_and_ensure_exclusive_use(tdc.stable_id).update!(referentiel: create(:api_referentiel, :autocomplete, hint: "après"))
    end

    it "uses the private annotation wording" do
      expect(subject).not_to have_text("du champ")
    end
  end

  describe "explication without libelle" do
    let(:procedure) { procedures.individual }
    let(:draft) { procedure.draft_revision }

    # the libelle is defaulted on creation, the admin empties it afterwards
    def add_explication(description:)
      draft.add_type_de_champ(type_champ: "explication", libelle: "Explication").update!(libelle: "", description:)
    end

    subject do
      render_inline(described_class.new(new_revision: draft.reload, previous_revision: procedure.published_revision))
      page
    end

    context "when it is added with a description" do
      before { add_explication(description: "Munissez-vous **de votre avis d’imposition** & d’un <b>justificatif</b> de domicile récent") }

      it "names it after its truncated description" do
        expect(subject).to have_text("Le champ « Munissez-vous de votre avis d’imposition & d’un… » a été ajouté.", normalize_ws: true)
      end
    end

    context "when it is added without a description" do
      before { add_explication(description: "") }

      it "names it after its type" do
        expect(subject).to have_text("Le champ « Explication » a été ajouté.", normalize_ws: true)
      end
    end

    context "when it is removed" do
      before { add_explication(description: "Lisez la notice") }

      subject do
        render_inline(described_class.new(new_revision: procedure.published_revision, previous_revision: draft.reload))
        page
      end

      it "names it after its description" do
        expect(subject).to have_text("Le champ « Lisez la notice » a été supprimé.", normalize_ws: true)
      end
    end

    context "when a champ with a libelle is added" do
      before { draft.add_type_de_champ(type_champ: "text", libelle: "Nom de l’association", mandatory: false) }

      it "keeps its libelle" do
        expect(subject).to have_text("Le champ « Nom de l’association » a été ajouté.", normalize_ws: true)
      end
    end
  end
end
