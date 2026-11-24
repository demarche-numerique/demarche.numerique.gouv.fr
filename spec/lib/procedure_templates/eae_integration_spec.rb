# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcedureTemplates::EaeIntegration do
  let_it_be(:deadline) { Date.current.next_occurring(:wednesday) + 4.weeks }
  # administrateurs.default is also a reviewer: one the builder could add to a team
  let_it_be(:procedure) { described_class.create!(administrateur: administrateurs.default, lien_dpo: "dpd@exemple.fr", deadline:) }
  let(:revision) { procedure.draft_revision }
  let(:types_de_champ) { revision.public_flat_type_de_champs }
  let(:pieces_justificatives) { types_de_champ.filter(&:piece_justificative?) }

  # A section and a field can share a label, as can a field and the child of a block.
  def type_de_champ(libelle)
    [*revision.public_root_type_de_champs, *revision.private_root_type_de_champs].find { it.libelle == libelle && !it.header_section? }
  end

  def answer(dossier, libelle, value)
    dossier.champ_for_update(type_de_champ(libelle), updated_by: dossier.user.email).update!(value:)

    Dossier.find(dossier.id)
  end

  it "creates a draft procedure with a short retention, kept off the public catalogue" do
    expect(procedure).to have_attributes(
      aasm_state: "brouillon",
      for_individual: true,
      for_tiers_enabled: false,
      ask_birthday: false,
      opendata: false,
      lien_dpo: "dpd@exemple.fr",
      duree_conservation_dossiers_dans_ds: 3
    )
  end

  it "asks no medical information" do
    libelles = revision.type_de_champs.map(&:libelle).join(" ")

    expect(libelles).not_to match(/vaccin|sanguin|dentaire|CEMPN|DGAC|allergie|mutuelle|certificat médical/i)
  end

  it "keeps the sections in the order of the notice" do
    expect(types_de_champ.filter(&:header_section?).map(&:libelle)).to eq([
      "Recrutement", "État civil", "Situation familiale", "Coordonnées", "Parents", "Diplômes et formations",
      "Situation militaire", "Emploi, solde et protection sociale", "Personne à prévenir en cas d’urgence",
      "Arrivée à l’école", "Préparation physique", "Mise en garde contre les stupéfiants et l’alcool",
    ])
  end

  it "watermarks identity documents and purges the most sensitive documents once reviewed" do
    expect(pieces_justificatives.filter(&:titre_identite?).map(&:libelle)).to eq([
      "Carte nationale d’identité (recto) ou passeport", "Carte nationale d’identité (verso)", "Passeport étranger",
    ])
    expect(pieces_justificatives.filter { it.pj_auto_purge? && !it.titre_identite? }.map(&:libelle)).to eq([
      "Acte de naissance", "Justificatifs de situation de famille", "Livret de famille",
      "Carte vitale (recto) ou attestation de droits", "Relevé d’identité bancaire (RIB)",
    ])
  end

  it "only asks a document from the applicants it concerns" do
    conditions = types_de_champ.filter { it.condition.present? }.to_h { [it.libelle, it.condition.to_s(revision.type_de_champs)] }

    expect(conditions).to include(
      "Concours d’admission" => "(Type de recrutement == Externe)",
      "Relevé d’identité bancaire (RIB)" => "(Type de recrutement == Externe)",
      "Grade actuel" => "(Type de recrutement == Interne)",
      "Passeport étranger" => "(Avez-vous une autre nationalité que la nationalité française ? == Oui)",
      "Photo d’identité" => "(Concours d’admission == Sur titre – licence option « sciences politiques »)",
      "Permis de conduire (recto et verso)" => "(Êtes-vous titulaire du permis de conduire ? == Oui)",
      "Justificatifs de situation de famille" => "((Situation familiale != Célibataire) || (Nombre d’enfants > 0))"
    )
    expect(type_de_champ("Lettre de convocation").condition).to be_nil
  end

  it "shows a conditional document once the applicant answers yes" do
    dossier = create(:dossier, procedure:, revision:)
    permis = type_de_champ("Permis de conduire (recto et verso)")
    expect(dossier.project_champ(permis)).not_to be_visible

    dossier = answer(dossier, "Êtes-vous titulaire du permis de conduire ?", "true")

    expect(dossier.project_champ(permis)).to be_visible
  end

  it "does not ask an internal applicant the documents the administration already holds" do
    dossier = answer(create(:dossier, procedure:, revision:), "Type de recrutement", "Interne")

    hidden = [
      "Concours d’admission", "Attestation de participation à la journée défense et citoyenneté (JDC)", "Avez-vous des antécédents militaires ?",
      "Occupez-vous actuellement un emploi civil ?", "Carte vitale (recto) ou attestation de droits", "Relevé d’identité bancaire (RIB)",
    ]
    shown = [
      "Grade actuel", "Unité et base d’affectation actuelles", "Numéro identifiant air (NIA) actuel", "Date d’entrée en service",
      "État signalétique et des services",
    ]

    expect(hidden.map { dossier.project_champ(type_de_champ(it)).visible? }).to all(be(false))
    expect(shown.map { dossier.project_champ(type_de_champ(it)).visible? }).to all(be(true))
  end

  it "asks the birth date in the field FranceConnect prefills" do
    birth_date = type_de_champ("Date de naissance")
    dossier = create(:dossier, procedure:, revision:, user: create(:user, :with_fci))

    dossier.prefill_champs_from_france_connect(updated_by: dossier.user.email)

    expect(birth_date).to be_birthdate.and be_prefill_with_france_connect_information
    expect(Dossier.find(dossier.id).project_champ(birth_date).value).to eq(dossier.user.france_connect_informations.sole.birthdate.iso8601)
  end

  it "can be published once the administrateur has set its service and zone" do
    administrateur = administrateurs.blank
    procedure = described_class.create!(administrateur:)
    procedure.update!(service: services.default, zones: [zones.default], lien_site_web: "https://www.exemple.fr")

    expect { procedure.publish_or_reopen!(administrateur, "integration-eae") }
      .to change { procedure.reload.aasm_state }.from("brouillon").to("publiee")
    expect(TypeDeChamp.where(id: procedure.published_revision.public_root_type_de_champs).dubious).to be_empty
  end

  it "groups the parents and the diplomas in repeatable blocks" do
    parent = type_de_champ("Parent")

    expect(parent).to have_attributes(max_repetitions: 2)
    expect(revision.children_of(parent).map(&:libelle)).to eq([
      "Lien de parenté", "Nom de naissance", "Prénoms", "Date de naissance", "Lieu de naissance", "Adresse", "Profession", "Téléphone portable",
    ])
    expect(revision.children_of(type_de_champ("Diplôme civil supérieur")).map(&:libelle)).to eq(["Libellé du diplôme", "Année d’obtention"])
  end

  it "gives the reviewers their instructions and two internal fields" do
    expect(revision.private_flat_type_de_champs.map { [it.type_champ, it.libelle] }).to eq([
      ["explication", "Consignes d’instruction"],
      ["checkbox", "Pièces originales vérifiées le jour de l’intégration"],
      ["textarea", "Observations du service"],
    ])
  end

  describe "the teams" do
    it "has one team per recruitment, the student administration being the default one" do
      expect(procedure).to be_routing_enabled
      expect(procedure.defaut_groupe_instructeur.label).to eq("Section administration élèves")
      expect(procedure.groupe_instructeurs.to_h { [it.label, it.humanized_routing_rule] }).to eq(
        "Bureau des ressources humaines" => "(Type de recrutement == Interne)",
        "Section administration élèves" => "(Type de recrutement == Externe)"
      )
      expect(procedure.groupe_instructeurs.reload.pluck(:valid_routing_rule, :unique_routing_rule)).to all(eq([true, true]))
    end

    it "leaves the choice of the reviewers of each team to the administrateur" do
      expect(procedure.groupe_instructeurs.flat_map(&:instructeurs)).to be_empty
    end

    it "sends an internal applicant to human resources, and any other to the student administration" do
      internal = answer(create(:dossier, procedure:, revision:), "Type de recrutement", "Interne")
      unanswered = create(:dossier, procedure:, revision:)

      [internal, unanswered].each { RoutingEngine.compute(it) }

      expect(internal.reload.groupe_instructeur.label).to eq("Bureau des ressources humaines")
      expect(unanswered.reload.groupe_instructeur.label).to eq("Section administration élèves")
    end
  end

  describe "the deadline" do
    let(:administrateur) { administrateurs.blank }
    let(:wednesday) { Date.current.next_occurring(:wednesday) }

    it "closes the procedure the night of the last day of submission" do
      expect(procedure.auto_archive_on).to eq(deadline + 1.day)
    end

    it "refuses a day whose eve gets no reminder" do
      expect { described_class.create!(administrateur:, deadline: wednesday.next_occurring(:monday)) }
        .to raise_error(ArgumentError, /no reminder/)
        .and not_change { administrateur.procedures.count }
    end

    it "refuses a day in the past" do
      expect { described_class.create!(administrateur:, deadline: wednesday - 4.weeks) }
        .to raise_error(ActiveRecord::RecordInvalid) { expect(it.record.errors).to be_of_kind(:auto_archive_on, :greater_than) }
    end
  end

  describe "the export templates" do
    let(:export_templates) { procedure.defaut_groupe_instructeur.export_templates }
    let(:dossier) { create(:dossier, procedure:, revision:, individual: build(:individual, nom: "Martin", prenom: "Zoé")) }

    it "shares both with the team that does not own them" do
      expect(export_templates.map { [it.kind, it.shared] }).to contain_exactly(["zip", true], ["xlsx", true])
      expect(procedure.groupe_instructeurs.find_by!(label: "Bureau des ressources humaines").export_templates).to be_empty
    end

    describe "of the documents" do
      let(:export_template) { export_templates.template_zip.sole }

      def attach(libelle, filename, content_type: "application/pdf")
        champ = dossier.champ_for_update(type_de_champ(libelle), updated_by: dossier.user.email)
        champ.piece_justificative_file.attach(io: StringIO.new("x"), filename:, content_type:, metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE })
        champ.save!
      end

      def zip_paths
        ActiveStorage::DownloadableFile
          .create_list_from_dossiers(dossiers: Dossier.where(id: dossier.id), user_profile: instructeurs.default, export_template:)
          .map(&:last)
      end

      it "names the files as the notice asks" do
        expect(export_template.dossier_folder.path(dossier)).to eq("Martin_Zoé_#{dossier.id}")
        expect(export_template.export_pdf.path(dossier)).to eq("Martin_Zoé_FicheRens")
        expect(export_template.pj(type_de_champ("Lettre de convocation")).path(dossier)).to eq("Martin_Zoé_Convocation")
        expect(export_template.pjs.map { it.path(dossier).delete_prefix("Martin_Zoé_") }).to eq([
          "EtatSignaletique", "Convocation", "NotesConcours", "ActeNaissance", "Ambassade", "Famille", "LivretFamille", "Scolarite", "PhotoIdentite", "PSC1",
          "JDC", "ContratsReserve", "ConvocationsReserve", "SoldesReserve", "DenonciationReserve", "EtatsServices",
          "AttestationEmployeur", "Permis", "SecuriteSociale", "RIB",
        ])
      end

      it "numbers the files of a document, in one folder per application, and leaves identity documents out" do
        attach("Lettre de convocation", "scan.pdf")
        attach("Diplômes ou relevés de notes à partir du baccalauréat", "bac.pdf")
        attach("Diplômes ou relevés de notes à partir du baccalauréat", "licence.pdf")
        attach("Carte nationale d’identité (recto) ou passeport", "cni.png", content_type: "image/png")

        expect(zip_paths).to contain_exactly(
          "Martin_Zoé_#{dossier.id}/Martin_Zoé_FicheRens.pdf",
          "Martin_Zoé_#{dossier.id}/Martin_Zoé_Convocation-01.pdf",
          "Martin_Zoé_#{dossier.id}/Martin_Zoé_Scolarite-01.pdf",
          "Martin_Zoé_#{dossier.id}/Martin_Zoé_Scolarite-02.pdf"
        )
      end
    end

    describe "of the spreadsheet for the HR information system" do
      let(:export_template) { export_templates.template_xlsx.sole }
      let(:headers) { export_template.exported_columns.map(&:libelle) }

      def line(dossier)
        Dossier.find(dossier.id)
          .spreadsheet_columns_xlsx(type_de_champs: procedure.type_de_champs_for_procedure_export.to_a, export_template:)
          .to_h { [it[0], it[1]] }
      end

      it "lists data only, and no internal field: a prefill link can fill those" do
        columns = export_template.exported_columns.map(&:column)

        expect(columns.map(&:type)).not_to include(:attachments)
        expect(columns.filter(&:champ_column?).map(&:stable_id) & revision.private_root_type_de_champs.map(&:stable_id)).to be_empty
        expect(headers).to start_with("N° dossier", "État", "Déposé le")
        expect(headers).to include("Nom", "Date de naissance", "Corps", "Code postal", "NID")
      end

      it "writes one line per application" do
        answer(dossier, "Type de recrutement", "Interne")
        answer(dossier, "Corps", "Base (BASE)")
        RoutingEngine.compute(answer(dossier, "Date de naissance", "2004-05-06"))

        expect(line(dossier)).to include(
          "N° dossier" => dossier.id, "Groupe instructeur" => "Bureau des ressources humaines", "Nom" => "Martin", "Prénom" => "Zoé",
          "Type de recrutement" => "Interne", "Corps" => "Base (BASE)", "Date de naissance" => Date.new(2004, 5, 6), "Concours" => nil
        )
        expect(line(dossier).keys).to eq(headers)
      end
    end
  end

  describe "the e-mails" do
    let(:dossier) do
      create(:dossier, :en_instruction, procedure:, revision:, individual: build(:individual, nom: "Martin", prenom: "Zoé"))
    end

    it "customises the acknowledgement and the start of the review, and keeps the others as the platform writes them" do
      expect(procedure.email_templates.filter(&:persisted?).map(&:class)).to contain_exactly(Emails::Depose, Emails::PasseEnInstruction)
      expect(procedure.email_templates.filter(&:persisted?)).to all(be_valid)
      expect(procedure).to be_valid(:publication)
    end

    it "acknowledges the submission and points to the submission receipt" do
      email = procedure.email_templates.find { it.is_a?(Emails::Depose) }

      expect(email.subject_for_dossier(dossier)).to eq("Votre dossier d’intégration n° #{dossier.id} a bien été déposé")
      expect(email.body_for_dossier(dossier)).to include("Bonjour Zoé Martin,", "L’attestation de dépôt est jointe à ce courriel", "/dossiers/#{dossier.id}")
      expect(email.body_for_dossier(dossier)).not_to include("--")
    end

    it "tells the applicant the application can no longer be changed once under review" do
      email = procedure.email_templates.find { it.is_a?(Emails::PasseEnInstruction) }

      expect(email.subject_for_dossier(dossier)).to eq("Votre dossier d’intégration n° #{dossier.id} est en cours d’examen")
      expect(email.body_for_dossier(dossier)).to include("Vous ne pouvez plus le modifier.")
      expect(email.body_for_dossier(dossier)).not_to include("--")
    end

    it "mentions the submission receipt on the page that follows the submission" do
      expect(revision.dossier_submitted_message.body_as_html).to include("Une attestation de dépôt vous est envoyée par courriel")
    end
  end
end
