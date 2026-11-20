# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcedureTemplates::EaeIntegration do
  let_it_be(:procedure) { described_class.create!(administrateur: administrateurs.blank, lien_dpo: "dpd@exemple.fr") }
  let(:revision) { procedure.draft_revision }
  let(:types_de_champ) { revision.public_flat_type_de_champs }
  let(:pieces_justificatives) { types_de_champ.filter(&:piece_justificative?) }

  def type_de_champ(libelle) = revision.type_de_champs.find { it.libelle == libelle }

  it "creates a draft procedure with a short retention, kept off the public catalogue" do
    expect(procedure).to have_attributes(
      aasm_state: "brouillon",
      for_individual: true,
      ask_birthday: true,
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

    question = type_de_champ("Êtes-vous titulaire du permis de conduire ?")
    dossier.champ_for_update(question, updated_by: dossier.user.email).update!(value: "true")

    expect(Dossier.find(dossier.id).project_champ(permis)).to be_visible
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

  it "leaves two private annotations to the reviewers" do
    expect(revision.private_flat_type_de_champs.map(&:libelle)).to eq([
      "Pièces originales vérifiées le jour de l’intégration", "Observations de la section administration élèves",
    ])
  end

  describe "the export template" do
    let(:export_template) { procedure.defaut_groupe_instructeur.export_templates.sole }
    let(:dossier) do
      create(:dossier, :en_construction, procedure:, revision:, individual: build(:individual, nom: "Martin", prenom: "Zoé"))
    end

    it "names the files as the notice asks" do
      expect(export_template).to be_shared
      expect(export_template.dossier_folder.path(dossier)).to eq("Martin_Zoé_#{dossier.id}")
      expect(export_template.export_pdf.path(dossier)).to eq("Martin_Zoé_FicheRens")
      expect(export_template.pj(type_de_champ("Lettre de convocation")).path(dossier)).to eq("Martin_Zoé_Convocation")
      expect(export_template.pjs.map { it.path(dossier).delete_prefix("Martin_Zoé_") }).to eq([
        "Convocation", "NotesConcours", "ActeNaissance", "Ambassade", "Famille", "LivretFamille", "Scolarite", "PhotoIdentite", "PSC1",
        "JDC", "ContratsReserve", "ConvocationsReserve", "SoldesReserve", "DenonciationReserve", "EtatsServices",
        "AttestationEmployeur", "Permis", "SecuriteSociale", "RIB",
      ])
    end
  end
end
