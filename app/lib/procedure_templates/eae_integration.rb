# frozen_string_literal: true

module ProcedureTemplates
  # Builds the draft procedure that replaces the e-mail, USB key and paper
  # transmission of the administrative documents asked by the integration
  # notice of the École de l'air et de l'espace (note N°46/EAE/DGFM/CMDT):
  # each document is uploaded once, and reviewers read it in place.
  #
  # Applicants of the internal recruitment already serve: the documents their
  # administration holds (JDC, social security, bank details, past services)
  # are not asked again.
  #
  # Medical documents are deliberately left out: the platform cannot hide a
  # champ from part of the reviewers of an application, and health data must
  # not reach the administrative team.
  #
  # The procedure comes out as a draft, with one team per recruitment and no
  # reviewer: the administrateur adds reviewers to both teams, sets the
  # service and publishes. See PrefillLink for the link sent to each applicant.
  class EaeIntegration
    include Logic

    TITLE = "Intégration à l’École de l’air et de l’espace"
    LEGAL_BASIS = "Note N°46/EAE/DGFM/CMDT – notice d’intégration des élèves issus du recrutement externe"

    # Months an application is kept once reviewed: the documents are then held
    # by the school's own systems, the platform only carries them.
    RETENTION_PERIOD = 3

    # Hours a generated export stays on the platform, whatever happens to the
    # applications it was made from.
    EXPORT_LIFETIME = Export::MAX_DUREE_CONSERVATION_EXPORT.in_hours.to_i

    # The default team: it also takes an application no routing rule matches.
    STUDENT_ADMINISTRATION_TEAM = "Section administration élèves"
    HUMAN_RESOURCES_TEAM = "Bureau des ressources humaines"

    EXTERNAL = "Externe"
    INTERNAL = "Interne"
    POLITICAL_SCIENCE = "Sur titre – licence option « sciences politiques »"
    ENTRANCE_EXAMS = [
      "Concours MP, PC, PSI, MPI (SCEI)",
      POLITICAL_SCIENCE,
      "Sur titre – licence option « sciences »",
      "Sur titre",
    ].freeze
    SINGLE = "Célibataire"
    MARITAL_STATUSES = [SINGLE, "Marié(e)", "Pacsé(e)", "En concubinage", "Divorcé(e)", "Veuf / veuve"].freeze
    TRAIN = "Train"

    DESCRIPTION = <<~TEXT
      Vous êtes admis à l’École de l’air et de l’espace par un concours du recrutement externe ou interne. Cette démarche remplace l’envoi de vos pièces administratives par courriel et leur copie sur clé USB : chaque pièce est déposée une seule fois.

      Elle remplace aussi la fiche de renseignements et la fiche de contact de la notice d’intégration (note n° 46/EAE/DGFM/CMDT).

      Les pièces médicales ne sont pas concernées : elles suivent le circuit du service médical indiqué dans la notice.
    TEXT

    DATA_PROTECTION_NOTICE = <<~TEXT
      Les informations et les pièces déposées ici servent uniquement à votre prise en compte administrative à l’École de l’air et de l’espace (état civil, solde, protection sociale, scolarité, personne à prévenir).

      Elles sont lues par la section administration élèves et le bureau des ressources humaines de l’école. Les informations et les pièces nécessaires à votre gestion sont reprises dans votre dossier administratif et dans le système d’information des ressources humaines.

      Dès que la décision est prise sur votre dossier, vos pièces d’identité, votre acte de naissance, vos justificatifs de situation de famille, votre justificatif de sécurité sociale et votre RIB sont supprimés de votre dossier sur cette plateforme. L’école en tire auparavant une archive pour votre dossier administratif, sans vos pièces d’identité : chaque archive reste disponible sur cette plateforme #{EXPORT_LIFETIME} heures au plus après sa génération. Le reste de votre dossier est supprimé environ #{RETENTION_PERIOD} mois après cette décision.

      Ne déposez aucun document médical dans cette démarche.

      Vous pouvez accéder à vos données, les faire rectifier ou vous opposer à leur traitement en écrivant au service indiqué en bas de page ou, lorsqu’il y figure, à son délégué à la protection des données.
    TEXT

    DUAL_NATIONALITY_NOTICE = <<~TEXT
      Référence : instruction n° 1005/ARM/DRH-AAE/SDGR/BGA du 13 juillet 2021, chapitre 1, paragraphe 1.1.1.

      « Les jeunes gens ayant la faculté de répudier ou de décliner la nationalité française doivent être avisés lors du dépôt de leur demande d’engagement et au moment de la signature de l’acte que le fait de contracter un engagement dans l’armée française leur fait perdre cette faculté. »
    TEXT

    DRUG_AND_ALCOHOL_WARNING = <<~TEXT
      Lisez l’annexe V de la notice d’intégration avant de cocher la case ci-dessous. Elle rappelle que :

      - aucune faute liée aux produits stupéfiants n’est tolérée dans l’armée de l’air et de l’espace ;
      - la consommation excessive d’alcool est sanctionnée ;
      - des tests de dépistage sont pratiqués dès la sélection et tout au long de la carrière ;
      - tout usage, détention ou trafic expose à des sanctions disciplinaires ou professionnelles, en plus des poursuites pénales.
    TEXT

    REVIEWER_INSTRUCTIONS = <<~TEXT
      - Vérifiez les pièces d’identité à l’écran : elles ne figurent ni dans l’archive des pièces ni dans les exports.
      - Générez puis téléchargez l’archive des pièces et l’export pour le SIRH avant de prendre une décision : à la décision, les pièces d’identité, l’acte de naissance, les justificatifs de situation de famille, le justificatif de sécurité sociale et le RIB sont supprimés définitivement du dossier. Une archive reste téléchargeable pendant #{EXPORT_LIFETIME} heures après sa génération, que la décision soit prise ou non, puis elle est supprimée à son tour.
      - Prenez une décision sur chaque dossier : tant qu’un dossier reste en construction ou en instruction, rien n’est supprimé. Le dossier est supprimé environ #{RETENTION_PERIOD} mois après la décision.
      - Pour faire corriger plusieurs pièces, listez-les dans une seule demande de correction : une seule demande peut être en attente par dossier, et le courriel envoyé au candidat ne reprend pas votre message.
      - Cochez vous-même la case « Pièces originales vérifiées le jour de l’intégration », après avoir vu les originaux. Le lien de dépôt permet au candidat de cocher cette case et de remplir « Observations du service » : la plateforme affiche alors « Donnée remplie automatiquement. » sous le champ, et cette mention y reste après votre propre saisie. Dès l’arrivée du dossier, et avant de générer l’archive ou un export, décochez la case si elle est cochée et effacez toute observation déjà saisie : la fiche de renseignements de l’archive (PDF) les reprend telles quelles sous le titre « Annotations privées », et les exports standards dans leurs colonnes.
    TEXT

    # The submission receipt is attached to this e-mail by the platform.
    SUBMISSION_EMAIL = {
      subject: "Votre dossier d’intégration n° --numéro du dossier-- a bien été déposé",
      body: <<~HTML,
        <p>Bonjour --prénom-- --nom--,</p>
        <p>Votre dossier n° --numéro du dossier-- pour la démarche « --libellé démarche-- » a bien été déposé le --date de dépôt--.</p>
        <p>L’attestation de dépôt est jointe à ce courriel : présentez-la le jour de l’intégration. Vous pouvez aussi la télécharger depuis la page de votre dossier.</p>
        <p>Ce dépôt ne vaut pas validation de vos pièces : elles vont être vérifiées. Si l’une d’elles doit être corrigée ou complétée, vous recevrez un courriel et la demande figurera dans la messagerie de votre dossier.</p>
        <p>Tant que l’examen de votre dossier n’a pas commencé, vous pouvez encore le modifier à cette adresse : --lien dossier--</p>
        <p>Cordialement,<br>--nom du service--</p>
      HTML
    }.freeze

    # Also received when the deadline passes: every submitted application then
    # goes under review at once, so the text does not speak of a reviewer.
    UNDER_REVIEW_EMAIL = {
      subject: "Votre dossier d’intégration n° --numéro du dossier-- est en cours d’examen",
      body: <<~HTML,
        <p>Bonjour --prénom-- --nom--,</p>
        <p>Votre dossier n° --numéro du dossier--, déposé le --date de dépôt--, est en cours d’examen depuis le --date de passage en instruction--. Vous ne pouvez plus le modifier.</p>
        <p>Si une pièce doit être corrigée ou complétée, vous recevrez un courriel et la demande figurera dans la messagerie de votre dossier : il redeviendra alors modifiable.</p>
        <p>Vous pouvez consulter votre dossier à cette adresse : --lien dossier--</p>
        <p>Cordialement,<br>--nom du service--</p>
      HTML
    }.freeze

    SUBMISSION_MESSAGE = "Votre dossier est déposé. Une attestation de dépôt vous est envoyée par courriel, et vous pouvez la télécharger depuis la page de votre dossier : présentez-la le jour de l’intégration."

    # The first columns of the spreadsheet for the HR information system. The
    # fields that carry a `spreadsheet_header` follow them, in the order of
    # the form: an export ignores the order of a template for fields.
    SPREADSHEET_APPLICATION_COLUMNS = {
      "self/id" => "N° dossier",
      "self/state" => "État",
      "self/depose_at" => "Déposé le",
      "self/en_instruction_at" => "Passé en instruction le",
      "self/processed_at" => "Traité le",
      "groupe_instructeur/id" => "Groupe instructeur",
      "individual/gender" => "Civilité",
      "individual/nom" => "Nom",
      "individual/prenom" => "Prénom",
      "self/user_email_for_display" => "Adresse électronique",
    }.freeze

    PUBLIC_FIELDS = [
      { type: :explication, libelle: "Protection de vos données", description: DATA_PROTECTION_NOTICE },

      { type: :header_section, libelle: "Recrutement" },
      {
        key: :recruitment,
        type: :drop_down_list,
        libelle: "Type de recrutement",
        spreadsheet_header: "Type de recrutement",
        description: "Interne si vous êtes déjà militaire d’active et admis par un concours interne. Les pièces que l’administration détient déjà ne vous sont alors pas redemandées.",
        drop_down_options: [EXTERNAL, INTERNAL],
      },
      {
        key: :entrance_exam,
        type: :drop_down_list,
        libelle: "Concours d’admission",
        spreadsheet_header: "Concours",
        drop_down_options: ENTRANCE_EXAMS,
        shown_if: -> { external },
      },
      { type: :text, libelle: "Grade actuel", spreadsheet_header: "Grade", shown_if: -> { internal } },
      { type: :text, libelle: "Unité et base d’affectation actuelles", spreadsheet_header: "Unité et base", shown_if: -> { internal } },
      { type: :text, libelle: "Numéro identifiant air (NIA) actuel", spreadsheet_header: "NIA actuel", shown_if: -> { internal } },
      {
        type: :date,
        libelle: "Date d’entrée en service",
        spreadsheet_header: "Date d’entrée en service",
        date_in_past: true,
        shown_if: -> { internal },
      },
      {
        type: :piece_justificative,
        libelle: "État signalétique et des services",
        mandatory: false,
        export_name: "EtatSignaletique",
        shown_if: -> { internal },
      },
      {
        key: :corps,
        type: :drop_down_list,
        libelle: "Corps",
        spreadsheet_header: "Corps",
        drop_down_options: ["Personnel navigant (PN)", "Mécanicien (MECA)", "Base (BASE)"],
      },
      { type: :drop_down_list, libelle: "Durée de scolarité", spreadsheet_header: "Durée de scolarité", drop_down_options: ["1 an", "3 ans"] },
      { type: :piece_justificative, libelle: "Lettre de convocation", export_name: "Convocation" },
      {
        type: :piece_justificative,
        libelle: "Relevé de notes au concours",
        description: "Épreuves académiques et sportives.",
        export_name: "NotesConcours",
      },

      { type: :header_section, libelle: "État civil" },
      { type: :text, libelle: "Nom marital", spreadsheet_header: "Nom marital", mandatory: false },
      {
        type: :text,
        libelle: "Prénoms",
        spreadsheet_header: "Prénoms",
        description: "Tous vos prénoms, dans l’ordre de l’état civil, séparés par une virgule.",
      },
      {
        type: :date,
        libelle: "Date de naissance",
        spreadsheet_header: "Date de naissance",
        # asked here rather than with the identity: it is the only birth date
        # FranceConnect prefills, and the only one a spreadsheet template exports
        birthdate: true,
        prefill_with_france_connect_information: true,
      },
      { type: :text, libelle: "Ville de naissance", spreadsheet_header: "Ville de naissance" },
      { type: :pays, libelle: "Pays de naissance", spreadsheet_header: "Pays de naissance" },
      {
        type: :departements,
        libelle: "Département de naissance",
        spreadsheet_header: "Département de naissance",
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

      {
        key: :dual_nationality,
        type: :yes_no,
        libelle: "Avez-vous une autre nationalité que la nationalité française ?",
        spreadsheet_header: "Double nationalité",
      },
      { type: :pays, libelle: "Autre nationalité", spreadsheet_header: "Autre nationalité", shown_if: -> { yes(:dual_nationality) } },
      {
        type: :date,
        libelle: "Date d’acquisition de cette nationalité",
        spreadsheet_header: "Date d’acquisition",
        date_in_past: true,
        shown_if: -> { yes(:dual_nationality) },
      },
      {
        type: :drop_down_list,
        libelle: "Mode d’acquisition de cette nationalité",
        spreadsheet_header: "Mode d’acquisition",
        drop_down_options: ["Naissance", "Mariage", "Arrivée dans le pays"],
        drop_down_other: true,
        shown_if: -> { yes(:dual_nationality) },
      },
      {
        type: :piece_justificative,
        nature: "titre_identite",
        libelle: "Passeport étranger",
        description: "Photo ou scan au format JPEG ou PNG.",
        shown_if: -> { yes(:dual_nationality) },
      },
      {
        type: :piece_justificative,
        libelle: "Document officiel attestant la double nationalité",
        description: "Délivré par une ambassade, un tribunal ou une mairie : il précise la date et le mode d’acquisition.",
        export_name: "Ambassade",
        shown_if: -> { yes(:dual_nationality) },
      },
      {
        type: :explication,
        libelle: "Attestation de double nationalité",
        description: DUAL_NATIONALITY_NOTICE,
        shown_if: -> { yes(:dual_nationality) },
      },
      {
        type: :checkbox,
        libelle: "J’atteste avoir été avisé(e) de ces dispositions et je suis pleinement conscient(e) que la souscription de mon contrat d’engagement me fait perdre la faculté de répudier la nationalité française",
        shown_if: -> { yes(:dual_nationality) },
      },

      { type: :header_section, libelle: "Situation familiale" },
      {
        key: :marital_status,
        type: :drop_down_list,
        libelle: "Situation familiale",
        spreadsheet_header: "Situation familiale",
        drop_down_options: MARITAL_STATUSES,
      },
      {
        key: :children_count,
        type: :integer_number,
        libelle: "Nombre d’enfants",
        spreadsheet_header: "Nombre d’enfants",
        positive_number: true,
      },
      {
        type: :piece_justificative,
        libelle: "Justificatifs de situation de famille",
        description: "Acte de mariage, attestation de PACS, certificat de vie maritale, extraits d’acte de naissance des enfants.",
        export_name: "Famille",
        pj_auto_purge: true,
        shown_if: -> { with_family },
      },
      {
        type: :piece_justificative,
        libelle: "Livret de famille",
        mandatory: false,
        export_name: "LivretFamille",
        pj_auto_purge: true,
        shown_if: -> { with_family },
      },

      { type: :header_section, libelle: "Coordonnées" },
      { type: :phone, libelle: "Téléphone portable personnel", spreadsheet_header: "Téléphone" },
      {
        type: :address,
        libelle: "Adresse postale",
        spreadsheet_header: { nil => "Adresse", "$.postal_code" => "Code postal", "$.city_name" => "Commune" },
      },

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
        spreadsheet_header: "INE",
        description: "Il figure sur votre relevé de notes du baccalauréat. Il sert à votre inscription à l’IEP d’Aix-en-Provence.",
        shown_if: -> { political_science },
      },
      {
        type: :piece_justificative,
        libelle: "Photo d’identité",
        description: "Pour votre inscription à l’IEP d’Aix-en-Provence.",
        export_name: "PhotoIdentite",
        pj_limit_formats: true,
        pj_format_families: ["image_scan"],
        shown_if: -> { political_science },
      },
      { key: :psc1, type: :yes_no, libelle: "Détenez-vous une attestation de formation aux premiers secours (PSC1) ?" },
      { type: :piece_justificative, libelle: "Attestation PSC1", export_name: "PSC1", shown_if: -> { yes(:psc1) } },

      { type: :header_section, libelle: "Situation militaire" },
      {
        type: :formatted,
        libelle: "Numéro identifiant défense (NID)",
        spreadsheet_header: "NID",
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
        shown_if: -> { external },
      },
      {
        key: :prior_service,
        type: :yes_no,
        libelle: "Avez-vous des antécédents militaires ?",
        description: "Période de réserve, EETAAE de Saintes, autre armée, lycée militaire, EPA de Grenoble, FMIR…",
        shown_if: -> { external },
      },
      {
        type: :textarea,
        libelle: "Antécédents militaires",
        description: "Pour chaque période : l’organisme, les années et la durée.",
        shown_if: -> { yes(:prior_service) },
      },
      {
        type: :text,
        libelle: "Numéro identifiant air (NIA)",
        spreadsheet_header: "NIA",
        description: "Si vous en détenez un.",
        mandatory: false,
        shown_if: -> { yes(:prior_service) },
      },
      {
        type: :piece_justificative,
        libelle: "Contrats d’engagement",
        description: "Contrats initiaux et renouvellements.",
        mandatory: false,
        export_name: "ContratsReserve",
        shown_if: -> { yes(:prior_service) },
      },
      {
        type: :piece_justificative,
        libelle: "Convocations aux périodes de réserve",
        mandatory: false,
        export_name: "ConvocationsReserve",
        shown_if: -> { yes(:prior_service) },
      },
      {
        type: :piece_justificative,
        libelle: "Fiches de solde",
        mandatory: false,
        export_name: "SoldesReserve",
        shown_if: -> { yes(:prior_service) },
      },
      {
        type: :piece_justificative,
        libelle: "Décision de dénonciation ou de résiliation du contrat de réserve",
        mandatory: false,
        export_name: "DenonciationReserve",
        shown_if: -> { yes(:prior_service) },
      },
      {
        type: :piece_justificative,
        libelle: "État des services antérieurs dans d’autres armées",
        mandatory: false,
        export_name: "EtatsServices",
        shown_if: -> { yes(:prior_service) },
      },

      { type: :header_section, libelle: "Emploi, solde et protection sociale" },
      { key: :civilian_job, type: :yes_no, libelle: "Occupez-vous actuellement un emploi civil ?", shown_if: -> { external } },
      {
        type: :piece_justificative,
        libelle: "Attestation de l’employeur vous libérant de votre emploi civil",
        export_name: "AttestationEmployeur",
        shown_if: -> { yes(:civilian_job) },
      },
      { key: :driving_licence, type: :yes_no, libelle: "Êtes-vous titulaire du permis de conduire ?", spreadsheet_header: "Permis de conduire" },
      { type: :piece_justificative, libelle: "Permis de conduire (recto et verso)", export_name: "Permis", shown_if: -> { yes(:driving_licence) } },
      {
        type: :piece_justificative,
        libelle: "Carte vitale (recto) ou attestation de droits",
        description: "À votre propre numéro, et non à celui de vos parents. L’attestation se télécharge sur ameli.fr.",
        export_name: "SecuriteSociale",
        pj_auto_purge: true,
        shown_if: -> { external },
      },
      {
        type: :piece_justificative,
        libelle: "Relevé d’identité bancaire (RIB)",
        description: "À vos nom et prénom.",
        export_name: "RIB",
        pj_auto_purge: true,
        shown_if: -> { external },
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
      { key: :parents_abroad, type: :yes_no, libelle: "Vos parents résident-ils à l’étranger ?" },
      { type: :text, libelle: "Nom de la personne à prévenir en France", shown_if: -> { yes(:parents_abroad) } },
      { type: :text, libelle: "Prénom de la personne à prévenir en France", shown_if: -> { yes(:parents_abroad) } },
      { type: :text, libelle: "Lien de parenté avec la personne à prévenir en France", shown_if: -> { yes(:parents_abroad) } },
      { type: :address, libelle: "Adresse de la personne à prévenir en France", shown_if: -> { yes(:parents_abroad) } },
      { type: :phone, libelle: "Téléphone de la personne à prévenir en France", shown_if: -> { yes(:parents_abroad) } },
      { type: :email, libelle: "Adresse électronique de la personne à prévenir en France", shown_if: -> { yes(:parents_abroad) } },

      { type: :header_section, libelle: "Arrivée à l’école" },
      {
        key: :transport,
        type: :drop_down_list,
        libelle: "Mode de transport pour rejoindre l’école",
        description: "Vous pouvez le compléter plus tard : votre dossier reste modifiable après son dépôt, tant que son examen n’a pas commencé.",
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
        key: :fitness_tests_done,
        type: :yes_no,
        libelle: "Avez-vous réalisé le demi-Cooper et le WOD de renforcement musculaire ?",
        description: "Si vous n’avez pas pu les réaliser, répondez non : n’indiquez aucun motif médical ici.",
        mandatory: false,
      },
      {
        type: :integer_number,
        libelle: "Demi-Cooper : distance parcourue en 6 minutes (en mètres)",
        positive_number: true,
        shown_if: -> { yes(:fitness_tests_done) },
      },
      {
        type: :formatted,
        libelle: "WOD : temps réalisé",
        description: "Minutes et secondes, par exemple 12:45.",
        formatted_mode: "advanced",
        expression_reguliere: "^[0-9]{1,2}:[0-5][0-9]$",
        expression_reguliere_exemple_text: "12:45",
        expression_reguliere_error_message: "Indiquez les minutes et les secondes, par exemple 12:45.",
        shown_if: -> { yes(:fitness_tests_done) },
      },

      { type: :header_section, libelle: "Mise en garde contre les stupéfiants et l’alcool" },
      { type: :explication, libelle: "Annexe V de la notice d’intégration", description: DRUG_AND_ALCOHOL_WARNING },
      { type: :checkbox, libelle: "Je reconnais avoir pris connaissance de l’attestation de mise en garde" },
    ].freeze

    # No internal field goes to the spreadsheet: a prefill link can set one
    # (tick the box, write the observations), so only a reviewer looking at the
    # application can vouch for it.
    INTERNAL_FIELDS = [
      { type: :explication, libelle: "Consignes d’instruction", description: REVIEWER_INSTRUCTIONS },
      { type: :checkbox, libelle: "Pièces originales vérifiées le jour de l’intégration" },
      { type: :textarea, libelle: "Observations du service" },
    ].freeze

    # What a field definition says to the builder, not to the platform.
    BUILDER_KEYS = [:key, :shown_if, :children, :export_name, :spreadsheet_header].freeze

    def self.create!(...) = new(...).create!

    # `deadline` is the last day an application can be submitted. The platform
    # has a single date for it: that night the procedure closes and every
    # submitted application goes under review.
    def initialize(administrateur:, lien_dpo: nil, deadline: nil)
      @administrateur = administrateur
      @lien_dpo = lien_dpo
      @deadline = deadline&.to_date
      @stable_ids = {}
      @export_names = {}
      @spreadsheet_headers = {}
    end

    def create!
      check_reminder_day!

      Procedure.transaction do
        create_procedure!
        add_fields(PUBLIC_FIELDS)
        add_fields(INTERNAL_FIELDS, private: true)
        create_teams!
        create_zip_export_template!
        create_spreadsheet_export_template!
        create_email_templates!
        create_submission_message!
        @procedure
      end
    end

    private

    # The platform reminds the applicants who have not submitted yet once, on
    # the eve of the deadline, and only from Monday to Friday.
    def check_reminder_day!
      return if @deadline.nil? || @deadline.yesterday.on_weekday?

      raise ArgumentError, "deadline #{@deadline.iso8601}: its eve is not a working day, so no reminder would be sent. Choose a day from Tuesday to Saturday."
    end

    def create_procedure!
      @procedure = Procedure.new(
        libelle: TITLE,
        description: DESCRIPTION,
        cadre_juridique: LEGAL_BASIS,
        lien_dpo: @lien_dpo,
        duree_conservation_dossiers_dans_ds: RETENTION_PERIOD,
        # stored as the platform does: the day after the last day of submission
        auto_archive_on: @deadline&.tomorrow,
        for_individual: true,
        # an admission is personal: nobody files for someone else, and the
        # identity step opens on the name the link carries
        for_tiers_enabled: false,
        # the definition of the form stays off the public catalogue
        opendata: false,
        allow_expert_review: false,
        administrateurs: [@administrateur]
      )
      @procedure.draft_revision = @procedure.revisions.build
      @procedure.save!
    end

    def add_fields(definitions, private: false, parent_stable_id: nil)
      definitions.reduce(nil) do |previous, definition|
        add_field(definition, private:, parent_stable_id:, after_stable_id: previous&.stable_id)
      end
    end

    def add_field(definition, private:, parent_stable_id:, after_stable_id:)
      definition => { type:, **attributes }
      key, shown_if, children, export_name, spreadsheet_header = attributes.values_at(*BUILDER_KEYS)

      type_de_champ = @procedure.draft_revision.add_type_de_champ(
        type_champ: TypeDeChamp.type_champs.fetch(type),
        private:,
        condition: shown_if && instance_exec(&shown_if),
        parent_stable_id:,
        after_stable_id:,
        **attributes.except(*BUILDER_KEYS)
      )
      if type_de_champ.errors.any?
        raise ArgumentError, "#{attributes[:libelle]}: #{type_de_champ.errors.full_messages.to_sentence}"
      end

      @stable_ids[key] = type_de_champ.stable_id if key
      @export_names[type_de_champ.stable_id] = export_name if export_name
      @spreadsheet_headers[type_de_champ.stable_id] = spreadsheet_header if spreadsheet_header
      add_fields(children, private:, parent_stable_id: type_de_champ.stable_id) if children

      type_de_champ
    end

    def value(key) = champ_value(@stable_ids.fetch(key))

    def yes(key) = ds_eq(value(key), constant(true))

    def external = ds_eq(value(:recruitment), constant(EXTERNAL))

    def internal = ds_eq(value(:recruitment), constant(INTERNAL))

    def political_science = ds_eq(value(:entrance_exam), constant(POLITICAL_SCIENCE))

    def with_family
      ds_or([
        ds_not_eq(value(:marital_status), constant(SINGLE)),
        greater_than(value(:children_count), constant(0)),
      ])
    end

    # Each recruitment has its team. The rules are read again each time the
    # applicant changes the answer, until the application is under review.
    def create_teams!
      @procedure.defaut_groupe_instructeur.update!(label: STUDENT_ADMINISTRATION_TEAM, routing_rule: external)
      @procedure.groupe_instructeurs.create!(label: HUMAN_RESOURCES_TEAM, routing_rule: internal)
      @procedure.toggle_routing
      @procedure.update_all_groupes_rule_statuses
    end

    # Names the files of a zip export as the notice asks: Nom_Prenom_Piece,
    # which the platform completes with the rank of the file (-01, -02…).
    # Both templates belong to the default team, the one that cannot be
    # deleted, and are shared with the other.
    def create_zip_export_template!
      ExportTemplate.create!(
        # longer, the export dialog of the reviewers cuts the name
        name: "Pièces nommées selon la notice",
        kind: "zip",
        shared: true,
        groupe_instructeur: @procedure.defaut_groupe_instructeur,
        dossier_folder: export_item(mention(TagsSubstitutionConcern::DOSSIER_ID_TAG)),
        export_pdf: export_item(text("FicheRens")),
        pjs: @export_names.map { |stable_id, name| export_item(text(name), stable_id:) }
      )
    end

    def export_item(suffix, stable_id: nil)
      name = [mention(individual_tag("individual_last_name")), text("_"), mention(individual_tag("individual_first_name")), text("_"), suffix]

      ExportItem.new(template: tiptap_doc(paragraph(*name)), enabled: true, stable_id:)
    end

    # One line per application, with the data of the form and no document.
    def create_spreadsheet_export_template!
      ExportTemplate.create!(
        name: "Alimentation du SIRH",
        kind: "xlsx",
        shared: true,
        groupe_instructeur: @procedure.defaut_groupe_instructeur,
        exported_columns: application_columns + field_columns
      )
    end

    def application_columns = SPREADSHEET_APPLICATION_COLUMNS.map { |column_id, header| exported_column(column_id, header) }

    def field_columns
      @spreadsheet_headers.flat_map do |stable_id, headers|
        headers = { nil => headers } if headers.is_a?(String)
        headers.map { |jsonpath, header| exported_column(["type_de_champ/#{stable_id}", jsonpath].compact.join("-"), header) }
      end
    end

    # An unknown column raises here: saved, an export would drop it silently.
    def exported_column(column_id, header)
      ExportedColumn.new(libelle: header, column: @procedure.find_column(h_id: { procedure_id: @procedure.id, column_id: }))
    end

    # The other e-mails keep the text of the platform, which follows the
    # language of the applicant.
    def create_email_templates!
      create_email_template!(Emails::Depose, **SUBMISSION_EMAIL)
      create_email_template!(Emails::PasseEnInstruction, **UNDER_REVIEW_EMAIL)
    end

    # The text is checked as written, where a tag that does not exist is an
    # error, then stored as the editor does: converted first, such a tag
    # would be kept as plain text.
    def create_email_template!(email_class, subject:, body:)
      email_template = email_class.new(procedure: @procedure, subject:, body:)
      email_template.validate!
      email_template.update!(json_subject: email_template.tiptap_subject_doc, json_body: email_template.tiptap_body_doc)
    end

    # Shown on the page that follows the submission.
    def create_submission_message!
      @procedure.draft_revision.create_dossier_submitted_message!(json_body: tiptap_doc(paragraph(text(SUBMISSION_MESSAGE))))
      @procedure.draft_revision.save!
    end

    def individual_tag(id) = TagsSubstitutionConcern::INDIVIDUAL_TAGS.find { it[:id] == id }

    def mention(tag) = { type: "mention", attrs: { id: tag[:id], label: tag[:libelle] } }

    def text(text) = { type: "text", text: }

    def paragraph(*content) = { type: "paragraph", content: }

    def tiptap_doc(*content) = { type: "doc", content: }
  end
end
