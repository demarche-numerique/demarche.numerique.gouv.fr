# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcedureTemplates::EaeIntegration::PrefillLink do
  let_it_be(:procedure) do
    administrateur = administrateurs.blank
    ProcedureTemplates::EaeIntegration.create!(administrateur:).tap do
      it.update!(service: services.default, zones: [zones.default], lien_site_web: "https://www.exemple.fr")
      it.publish_or_reopen!(administrateur, "integration-eae")
    end
  end
  let(:applicant) do
    { last_name: "Martin", first_name: "Zoé", recruitment: "Externe", entrance_exam: "Concours MP, PC, PSI, MPI (SCEI)", corps: "Base (BASE)" }
  end

  def params(url) = Rack::Utils.parse_nested_query(URI(url).query)

  # what the platform does when the link is opened
  def prefilled_dossier(url)
    dossier = Dossier.new(revision: procedure.published_revision, state: Dossier.states.fetch(:brouillon), prefilled: true)
    dossier.build_default_values
    dossier.save!
    dossier.prefill!(PrefillChamps.new(dossier, params(url)).to_a, PrefillIdentity.new(dossier, params(url)).to_h)

    Dossier.find(dossier.id)
  end

  def value(dossier, libelle) = dossier.project_champ(procedure.published_revision.public_root_type_de_champs.find { it.libelle == libelle }).value

  describe ".url" do
    it "opens the procedure with what the school knows about the applicant" do
      url = described_class.url(procedure, **applicant)
      dossier = prefilled_dossier(url)

      expect(url).to start_with("http://test.host/commencer/integration-eae?")
      expect(dossier.individual).to have_attributes(nom: "Martin", prenom: "Zoé")
      expect(["Type de recrutement", "Concours d’admission", "Corps"].map { value(dossier, it) }).to eq(applicant.values_at(:recruitment, :entrance_exam, :corps))
    end

    it "carries no name when none is given" do
      expect(params(described_class.url(procedure, recruitment: "Interne", corps: "Base (BASE)")).keys).to all(start_with("champ_"))
    end

    it "keeps the name it carries out of the logs" do
      filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(params(described_class.url(procedure, **applicant)))

      expect(filtered).to include("identite_nom" => "[FILTERED]", "identite_prenom" => "[FILTERED]")
    end

    it "refuses a value the platform would drop" do
      expect { described_class.url(procedure, recruitment: "externe") }.to raise_error(ArgumentError, /Type de recrutement: "externe" is not one of Externe et Interne/)
      expect { described_class.url(procedure, grade: "Sergent") }.to raise_error(ArgumentError, /grade is not prefilled/)
    end

    it "refuses a procedure that is not published, whose address is not final" do
      expect { described_class.url(procedures.brouillon, **applicant) }.to raise_error(ArgumentError, /must be published/)
    end
  end

  describe ".csv" do
    it "adds a link to each line of the list of the school" do
      list = "nom;prenom;recrutement;concours;corps\nMartin;Zoé;Externe;Sur titre;Base (BASE)\nPetit;Léa;Interne;;Mécanicien (MECA)\n"

      rows = CSV.parse(described_class.csv(procedure, list), headers: true, col_sep: ";")

      expect(rows.headers).to eq(["nom", "prenom", "recrutement", "concours", "corps", "lien"])
      expect(rows.map { it["nom"] }).to eq(["Martin", "Petit"])
      expect(value(prefilled_dossier(rows[1]["lien"]), "Corps")).to eq("Mécanicien (MECA)")
    end

    it "reads a list saved by a spreadsheet: byte order mark, Windows-1252, empty lines" do
      list = "nom;prenom;corps\r\nMartin;Zoé;Mécanicien (MECA)\r\n;;\r\nPetit;Léa;Base (BASE)\r\n"
      saved = ["\uFEFF#{list}", list.encode(Encoding::WINDOWS_1252).force_encoding(Encoding::UTF_8), list.b]

      links = saved.map { CSV.parse(described_class.csv(procedure, it), headers: true, col_sep: ";")["lien"] }

      expect(links.uniq.sole).to match([/identite_prenom=Zo%C3%A9/, nil, /identite_nom=Petit/])
    end

    it "names the line of a value it refuses" do
      list = "nom,recrutement\nMartin,Externe\nPetit,Extern\n"

      expect { described_class.csv(procedure, list) }.to raise_error(ArgumentError, /line 3: Type de recrutement/)
    end

    it "refuses a column it does not know" do
      expect { described_class.csv(procedure, "nom,grade\nMartin,Sergent\n") }.to raise_error(ArgumentError, /unknown columns: grade/)
    end
  end
end
