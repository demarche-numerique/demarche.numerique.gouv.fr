# frozen_string_literal: true

module ProcedureTemplates
  # Builds the draft procedure that replaces the e-mail, USB key and paper
  # transmission of the administrative documents asked by the integration
  # notice of the École de l'air et de l'espace (note N°46/EAE/DGFM/CMDT):
  # each document is uploaded once, and reviewers read it in place.
  #
  # Medical documents are deliberately left out: the platform cannot hide a
  # champ from part of the reviewers of an application, and health data must
  # not reach the administrative team.
  class EaeIntegration
    include Logic

    LIBELLE = "Intégration à l’École de l’air et de l’espace – recrutement externe"
    CADRE_JURIDIQUE = "Note N°46/EAE/DGFM/CMDT – notice d’intégration des élèves issus du recrutement externe"

    # Months an application is kept once reviewed: the documents are then held
    # by the school's own systems, the platform only carries them.
    DUREE_CONSERVATION = 3

    SCIENCES_POLITIQUES = "Sur titre – licence option « sciences politiques »"
    CONCOURS = [
      "Concours MP, PC, PSI, MPI (SCEI)",
      SCIENCES_POLITIQUES,
      "Sur titre – licence option « sciences »",
      "Sur titre",
    ].freeze
    CELIBATAIRE = "Célibataire"
    SITUATIONS_FAMILIALES = [CELIBATAIRE, "Marié(e)", "Pacsé(e)", "En concubinage", "Divorcé(e)", "Veuf / veuve"].freeze
    TRAIN = "Train"

    DESCRIPTION = <<~TEXT
      Vous êtes admis à l’École de l’air et de l’espace par un concours du recrutement externe. Cette démarche remplace l’envoi de vos pièces administratives par courriel et leur copie sur clé USB : chaque pièce est déposée une seule fois.

      Elle remplace aussi la fiche de renseignements et la fiche de contact de la notice d’intégration.

      Les pièces médicales ne sont pas concernées : elles suivent le circuit du service médical indiqué dans la notice.
    TEXT

    INFORMATION_RGPD = <<~TEXT
      Les informations et les pièces déposées ici servent uniquement à votre prise en compte administrative à l’École de l’air et de l’espace (état civil, solde, protection sociale, scolarité, personne à prévenir).

      Elles sont lues par la section administration élèves et le bureau des ressources humaines de l’école, et par personne d’autre.

      Votre dossier est supprimé de cette plateforme #{DUREE_CONSERVATION} mois après son traitement. Vos pièces d’identité et votre justificatif de sécurité sociale sont supprimés dès le traitement.

      Ne déposez aucun document médical dans cette démarche.

      Vous pouvez accéder à vos données, les faire rectifier ou vous opposer à leur traitement en écrivant au délégué à la protection des données indiqué en bas de page.
    TEXT

    ATTESTATION_DOUBLE_NATIONALITE = <<~TEXT
      Référence : instruction n° 1005/ARM/DRH-AAE/SDGR/BGA du 13 juillet 2021, chapitre 1, paragraphe 1.1.1.

      « Les jeunes gens ayant la faculté de répudier ou de décliner la nationalité française doivent être avisés lors du dépôt de leur demande d’engagement et au moment de la signature de l’acte que le fait de contracter un engagement dans l’armée française leur fait perdre cette faculté. »
    TEXT

    MISE_EN_GARDE_STUPEFIANTS = <<~TEXT
      Lisez l’annexe V de la notice d’intégration avant de cocher la case ci-dessous. Elle rappelle que :

      - aucune faute liée aux produits stupéfiants n’est tolérée dans l’armée de l’air et de l’espace ;
      - la consommation excessive d’alcool est sanctionnée ;
      - des tests de dépistage sont pratiqués dès la sélection et tout au long de la carrière ;
      - tout usage, détention ou trafic expose à des sanctions disciplinaires ou professionnelles, en plus des poursuites pénales.
    TEXT

    PUBLIC_CHAMPS = [
      { type: :explication, libelle: "Protection de vos données", description: INFORMATION_RGPD },

      { type: :header_section, libelle: "Recrutement" },
      { key: :concours, type: :drop_down_list, libelle: "Concours d’admission", drop_down_options: CONCOURS },
      {
        type: :drop_down_list,
        libelle: "Corps",
        drop_down_options: ["Personnel navigant (PN)", "Mécanicien (MECA)", "Base (BASE)"],
      },
      { type: :drop_down_list, libelle: "Durée de scolarité", drop_down_options: ["1 an", "3 ans"] },
      { type: :piece_justificative, libelle: "Lettre de convocation", export_name: "Convocation" },
      {
        type: :piece_justificative,
        libelle: "Relevé de notes au concours",
        description: "Épreuves académiques et sportives.",
        export_name: "NotesConcours",
      },

      { type: :header_section, libelle: "État civil" },
      { type: :text, libelle: "Nom marital", mandatory: false },
      {
        type: :text,
        libelle: "Prénoms",
        description: "Tous vos prénoms, dans l’ordre de l’état civil, séparés par une virgule.",
      },
      { type: :text, libelle: "Ville de naissance" },
      { type: :pays, libelle: "Pays de naissance" },
      {
        type: :departements,
        libelle: "Département de naissance",
        description: "Si vous êtes né(e) en France.",
        mandatory: false,
      },
      {
        type: :piece_justificative,
        libelle: "Acte de naissance",
        description: "Copie intégrale de moins de 3 mois.",
        export_name: "ActeNaissance",
        pj_auto_purge: true,
      },
      {
        type: :piece_justificative,
        nature: "titre_identite",
        libelle: "Carte nationale d’identité (recto) ou passeport",
        description: "En cours de validité. Photo ou scan au format JPEG ou PNG.",
      },
      {
        type: :piece_justificative,
        nature: "titre_identite",
        libelle: "Carte nationale d’identité (verso)",
        mandatory: false,
      },

      { key: :double_nationalite, type: :yes_no, libelle: "Avez-vous une autre nationalité que la nationalité française ?" },
      { type: :pays, libelle: "Autre nationalité", shown_if: -> { yes(:double_nationalite) } },
      { type: :date, libelle: "Date d’acquisition de cette nationalité", date_in_past: true, shown_if: -> { yes(:double_nationalite) } },
      {
        type: :drop_down_list,
        libelle: "Mode d’acquisition de cette nationalité",
        drop_down_options: ["Naissance", "Mariage", "Arrivée dans le pays"],
        drop_down_other: true,
        shown_if: -> { yes(:double_nationalite) },
      },
      {
        type: :piece_justificative,
        nature: "titre_identite",
        libelle: "Passeport étranger",
        description: "Photo ou scan au format JPEG ou PNG.",
        shown_if: -> { yes(:double_nationalite) },
      },
      {
        type: :piece_justificative,
        libelle: "Document officiel attestant la double nationalité",
        description: "Délivré par une ambassade, un tribunal ou une mairie : il précise la date et le mode d’acquisition.",
        export_name: "Ambassade",
        shown_if: -> { yes(:double_nationalite) },
      },
      {
        type: :explication,
        libelle: "Attestation de double nationalité",
        description: ATTESTATION_DOUBLE_NATIONALITE,
        shown_if: -> { yes(:double_nationalite) },
      },
      {
        type: :checkbox,
        libelle: "J’atteste avoir été avisé(e) de ces dispositions et je suis pleinement conscient(e) que la souscription de mon contrat d’engagement me fait perdre la faculté de répudier la nationalité française",
        shown_if: -> { yes(:double_nationalite) },
      },

      { type: :header_section, libelle: "Situation familiale" },
      { key: :situation_familiale, type: :drop_down_list, libelle: "Situation familiale", drop_down_options: SITUATIONS_FAMILIALES },
      { key: :enfants, type: :integer_number, libelle: "Nombre d’enfants", positive_number: true },
      {
        type: :piece_justificative,
        libelle: "Justificatifs de situation de famille",
        description: "Acte de mariage, attestation de PACS, certificat de vie maritale, extraits d’acte de naissance des enfants.",
        export_name: "Famille",
        pj_auto_purge: true,
        shown_if: -> { charge_de_famille },
      },
      {
        type: :piece_justificative,
        libelle: "Livret de famille",
        mandatory: false,
        export_name: "LivretFamille",
        pj_auto_purge: true,
        shown_if: -> { charge_de_famille },
      },

      { type: :header_section, libelle: "Coordonnées" },
      { type: :phone, libelle: "Téléphone portable personnel" },
      { type: :address, libelle: "Adresse postale" },

      { type: :header_section, libelle: "Parents" },
      {
        type: :repetition,
        libelle: "Parent",
        description: "Ces renseignements sont demandés par la fiche de renseignements de la notice. Informez vos parents que vous les communiquez à l’école.",
        mandatory: false,
        limit_repetitions: true,
        max_repetitions: 2,
        children: [
          { type: :drop_down_list, libelle: "Lien de parenté", drop_down_options: ["Père", "Mère"] },
          { type: :text, libelle: "Nom de naissance" },
          { type: :text, libelle: "Prénoms" },
          { type: :date, libelle: "Date de naissance", date_in_past: true },
          { type: :text, libelle: "Lieu de naissance" },
          { type: :address, libelle: "Adresse" },
          { type: :text, libelle: "Profession", mandatory: false },
          { type: :phone, libelle: "Téléphone portable", mandatory: false },
        ],
      },

      { type: :header_section, libelle: "Diplômes et formations" },
      {
        type: :repetition,
        libelle: "Diplôme civil supérieur",
        mandatory: false,
        children: [
          { type: :text, libelle: "Libellé du diplôme" },
          { type: :integer_number, libelle: "Année d’obtention", positive_number: true },
        ],
      },
      {
        type: :piece_justificative,
        libelle: "Diplômes ou relevés de notes à partir du baccalauréat",
        export_name: "Scolarite",
      },
      {
        type: :text,
        libelle: "Numéro INE ou BEA",
        description: "Il figure sur votre relevé de notes du baccalauréat. Il sert à votre inscription à l’IEP d’Aix-en-Provence.",
        shown_if: -> { sciences_politiques },
      },
      {
        type: :piece_justificative,
        libelle: "Photo d’identité",
        description: "Pour votre inscription à l’IEP d’Aix-en-Provence.",
        export_name: "PhotoIdentite",
        pj_limit_formats: true,
        pj_format_families: ["image_scan"],
        shown_if: -> { sciences_politiques },
      },
      { key: :psc1, type: :yes_no, libelle: "Détenez-vous une attestation de formation aux premiers secours (PSC1) ?" },
      { type: :piece_justificative, libelle: "Attestation PSC1", export_name: "PSC1", shown_if: -> { yes(:psc1) } },

      { type: :header_section, libelle: "Situation militaire" },
      {
        type: :formatted,
        libelle: "Numéro identifiant défense (NID)",
        description: "Les 10 chiffres indiqués sur votre attestation de JDC, sans espace. Si vous avez été recensé(e) à l’étranger, demandez-le à l’ambassade de France.",
        formatted_mode: "simple",
        numbers_accepted: true,
        letters_accepted: false,
        special_characters_accepted: false,
        min_character_length: 10,
        max_character_length: 10,
      },
      {
        type: :piece_justificative,
        libelle: "Attestation de participation à la journée défense et citoyenneté (JDC)",
        export_name: "JDC",
      },
      {
        key: :services_anterieurs,
        type: :yes_no,
        libelle: "Avez-vous des antécédents militaires ?",
        description: "Période de réserve, EETAAE de Saintes, autre armée, lycée militaire, EPA de Grenoble, FMIR…",
      },
      {
        type: :textarea,
        libelle: "Antécédents militaires",
        description: "Pour chaque période : l’organisme, les années et la durée.",
        shown_if: -> { yes(:services_anterieurs) },
      },
      {
        type: :text,
        libelle: "Numéro identifiant air (NIA)",
        description: "Si vous en détenez un.",
        mandatory: false,
        shown_if: -> { yes(:services_anterieurs) },
      },
      {
        type: :piece_justificative,
        libelle: "Contrats d’engagement",
        description: "Contrats initiaux et renouvellements.",
        mandatory: false,
        export_name: "ContratsReserve",
        shown_if: -> { yes(:services_anterieurs) },
      },
      {
        type: :piece_justificative,
        libelle: "Convocations aux périodes de réserve",
        mandatory: false,
        export_name: "ConvocationsReserve",
        shown_if: -> { yes(:services_anterieurs) },
      },
      {
        type: :piece_justificative,
        libelle: "Fiches de solde",
        mandatory: false,
        export_name: "SoldesReserve",
        shown_if: -> { yes(:services_anterieurs) },
      },
      {
        type: :piece_justificative,
        libelle: "Décision de dénonciation ou de résiliation du contrat de réserve",
        mandatory: false,
        export_name: "DenonciationReserve",
        shown_if: -> { yes(:services_anterieurs) },
      },
      {
        type: :piece_justificative,
        libelle: "État des services antérieurs dans d’autres armées",
        mandatory: false,
        export_name: "EtatsServices",
        shown_if: -> { yes(:services_anterieurs) },
      },

      { type: :header_section, libelle: "Emploi, solde et protection sociale" },
      { key: :emploi_civil, type: :yes_no, libelle: "Occupez-vous actuellement un emploi civil ?" },
      {
        type: :piece_justificative,
        libelle: "Attestation de l’employeur vous libérant de votre emploi civil",
        export_name: "AttestationEmployeur",
        shown_if: -> { yes(:emploi_civil) },
      },
      { key: :permis, type: :yes_no, libelle: "Êtes-vous titulaire du permis de conduire ?" },
      { type: :piece_justificative, libelle: "Permis de conduire (recto et verso)", export_name: "Permis", shown_if: -> { yes(:permis) } },
      {
        type: :piece_justificative,
        libelle: "Carte vitale (recto) ou attestation de droits",
        description: "À votre propre numéro, et non à celui de vos parents. L’attestation se télécharge sur ameli.fr.",
        export_name: "SecuriteSociale",
        pj_auto_purge: true,
      },
      {
        type: :piece_justificative,
        libelle: "Relevé d’identité bancaire (RIB)",
        description: "À vos nom et prénom.",
        export_name: "RIB",
        pj_auto_purge: true,
      },

      { type: :header_section, libelle: "Personne à prévenir en cas d’urgence" },
      {
        type: :explication,
        libelle: "Une personne joignable pendant toute la période bloquée",
        description: "Vous n’aurez ni téléphone ni accès à internet pendant au moins les six premières semaines. Cette personne doit pouvoir être jointe en cas d’incident et suivre vos démarches personnelles en cours. Informez-la que vous communiquez ses coordonnées à l’école.",
      },
      { type: :text, libelle: "Nom de la personne à prévenir" },
      { type: :text, libelle: "Prénom de la personne à prévenir" },
      { type: :text, libelle: "Lien de parenté avec la personne à prévenir" },
      { type: :address, libelle: "Adresse de la personne à prévenir" },
      { type: :phone, libelle: "Téléphone de la personne à prévenir", description: "Un portable de préférence." },
      { type: :email, libelle: "Adresse électronique de la personne à prévenir" },
      { key: :parents_etranger, type: :yes_no, libelle: "Vos parents résident-ils à l’étranger ?" },
      { type: :text, libelle: "Nom de la personne à prévenir en France", shown_if: -> { yes(:parents_etranger) } },
      { type: :text, libelle: "Prénom de la personne à prévenir en France", shown_if: -> { yes(:parents_etranger) } },
      { type: :text, libelle: "Lien de parenté avec la personne à prévenir en France", shown_if: -> { yes(:parents_etranger) } },
      { type: :address, libelle: "Adresse de la personne à prévenir en France", shown_if: -> { yes(:parents_etranger) } },
      { type: :phone, libelle: "Téléphone de la personne à prévenir en France", shown_if: -> { yes(:parents_etranger) } },
      { type: :email, libelle: "Adresse électronique de la personne à prévenir en France", shown_if: -> { yes(:parents_etranger) } },

      { type: :header_section, libelle: "Arrivée à l’école" },
      {
        key: :transport,
        type: :drop_down_list,
        libelle: "Mode de transport pour rejoindre l’école",
        description: "Vous pouvez le compléter plus tard : votre dossier reste modifiable après son dépôt.",
        mandatory: false,
        drop_down_options: [TRAIN, "Véhicule personnel"],
        drop_down_other: true,
      },
      {
        type: :drop_down_list,
        libelle: "Gare d’arrivée",
        drop_down_options: ["Aix-en-Provence TGV", "Salon-de-Provence"],
        shown_if: -> { ds_eq(value(:transport), constant(TRAIN)) },
      },
      {
        type: :datetime,
        libelle: "Date et heure d’arrivée en gare",
        shown_if: -> { ds_eq(value(:transport), constant(TRAIN)) },
      },

      { type: :header_section, libelle: "Préparation physique" },
      {
        key: :tests_realises,
        type: :yes_no,
        libelle: "Avez-vous réalisé le demi-Cooper et le WOD de renforcement musculaire ?",
        description: "Si vous n’avez pas pu les réaliser, répondez non : n’indiquez aucun motif médical ici.",
        mandatory: false,
      },
      {
        type: :integer_number,
        libelle: "Demi-Cooper : distance parcourue en 6 minutes (en mètres)",
        positive_number: true,
        shown_if: -> { yes(:tests_realises) },
      },
      {
        type: :formatted,
        libelle: "WOD : temps réalisé",
        description: "Minutes et secondes, par exemple 12:45.",
        formatted_mode: "advanced",
        expression_reguliere: "^[0-9]{1,2}:[0-5][0-9]$",
        expression_reguliere_exemple_text: "12:45",
        expression_reguliere_error_message: "Indiquez les minutes et les secondes, par exemple 12:45.",
        shown_if: -> { yes(:tests_realises) },
      },

      { type: :header_section, libelle: "Mise en garde contre les stupéfiants et l’alcool" },
      { type: :explication, libelle: "Annexe V de la notice d’intégration", description: MISE_EN_GARDE_STUPEFIANTS },
      { type: :checkbox, libelle: "Je reconnais avoir pris connaissance de l’attestation de mise en garde" },
    ].freeze

    PRIVATE_CHAMPS = [
      { type: :checkbox, libelle: "Pièces originales vérifiées le jour de l’intégration" },
      { type: :textarea, libelle: "Observations de la section administration élèves" },
    ].freeze

    def self.create!(...) = new(...).create!

    def initialize(administrateur:, lien_dpo: nil)
      @administrateur = administrateur
      @lien_dpo = lien_dpo
      @stable_ids = {}
      @export_names = {}
    end

    def create!
      Procedure.transaction do
        create_procedure!
        add_champs(PUBLIC_CHAMPS)
        add_champs(PRIVATE_CHAMPS, private: true)
        create_export_template!
        @procedure
      end
    end

    private

    def create_procedure!
      @procedure = Procedure.new(
        libelle: LIBELLE,
        description: DESCRIPTION,
        cadre_juridique: CADRE_JURIDIQUE,
        lien_dpo: @lien_dpo,
        duree_conservation_dossiers_dans_ds: DUREE_CONSERVATION,
        for_individual: true,
        ask_birthday: true,
        # the definition of the form stays off the public catalogue
        opendata: false,
        allow_expert_review: false,
        administrateurs: [@administrateur]
      )
      @procedure.draft_revision = @procedure.revisions.build
      @procedure.save!
    end

    def add_champs(definitions, private: false, parent_stable_id: nil)
      definitions.reduce(nil) do |previous, definition|
        add_champ(definition, private:, parent_stable_id:, after_stable_id: previous&.stable_id)
      end
    end

    def add_champ(definition, private:, parent_stable_id:, after_stable_id:)
      definition => { type:, **attributes }
      key, shown_if, children, export_name = attributes.values_at(:key, :shown_if, :children, :export_name)

      type_de_champ = @procedure.draft_revision.add_type_de_champ(
        type_champ: TypeDeChamp.type_champs.fetch(type),
        private:,
        condition: shown_if && instance_exec(&shown_if),
        parent_stable_id:,
        after_stable_id:,
        **attributes.except(:key, :shown_if, :children, :export_name)
      )
      if type_de_champ.errors.any?
        raise ArgumentError, "#{attributes[:libelle]}: #{type_de_champ.errors.full_messages.to_sentence}"
      end

      @stable_ids[key] = type_de_champ.stable_id if key
      @export_names[type_de_champ.stable_id] = export_name if export_name
      add_champs(children, private:, parent_stable_id: type_de_champ.stable_id) if children

      type_de_champ
    end

    def value(key) = champ_value(@stable_ids.fetch(key))

    def yes(key) = ds_eq(value(key), constant(true))

    def sciences_politiques = ds_eq(value(:concours), constant(SCIENCES_POLITIQUES))

    def charge_de_famille
      ds_or([
        ds_not_eq(value(:situation_familiale), constant(CELIBATAIRE)),
        greater_than(value(:enfants), constant(0)),
      ])
    end

    # Names the files of a zip export as the notice asks: Nom_Prenom_Piece.
    def create_export_template!
      ExportTemplate.create!(
        name: "Pièces nommées selon la notice d’intégration",
        kind: "zip",
        shared: true,
        groupe_instructeur: @procedure.defaut_groupe_instructeur,
        dossier_folder: export_item(mention(TagsSubstitutionConcern::DOSSIER_ID_TAG)),
        export_pdf: export_item(text("FicheRens")),
        pjs: @export_names.map { |stable_id, name| export_item(text(name), stable_id:) }
      )
    end

    def export_item(suffix, stable_id: nil)
      content = [mention(individual_tag("individual_last_name")), text("_"), mention(individual_tag("individual_first_name")), text("_"), suffix]

      ExportItem.new(template: { type: "doc", content: [{ type: "paragraph", content: }] }, enabled: true, stable_id:)
    end

    def individual_tag(id) = TagsSubstitutionConcern::INDIVIDUAL_TAGS.find { it[:id] == id }

    def mention(tag) = { type: "mention", attrs: { id: tag[:id], label: tag[:libelle] } }

    def text(text) = { type: "text", text: }
  end
end
