# frozen_string_literal: true

module LLM
  class StructureImprover < BaseImprover
    TOOL_DEFINITION = {
      type: 'function',
      function: {
        name: LLMRuleSuggestion.rules.fetch('improve_structure'),
        description: 'Propose une amélioration de la structure du formulaire.',
        parameters: {
          type: 'object',
          properties: {
            add: {
              type: 'object',
              description: 'Ajout d\'une nouvelle header_section.',
              properties: {
                generated_stable_id: { type: 'integer', description: "Identifiant stable unique du nouveau header_section. Génère en entier negatif auto-décrémenté en partant de -1" },
                after_stable_id: { type: ['integer', 'null'], description: "Identifiant du champ après lequel la header_section doit être ajoutée : elle est placée au même endroit que lui, dans la même section s'il est dans une section. Après une header_section, elle est placée après tous les champs que celle-ci contient. Utiliser null UNIQUEMENT si le header_section doit être positionné en premier." },
                parent_stable_id: { type: ['integer', 'null'], description: "Quand after_stable_id est null : identifiant de la header_section dans laquelle placer la nouvelle en premier (un generated_stable_id pour une section que tu ajoutes). null pour le début du formulaire." },
                libelle: { type: 'string', description: 'Libellé de la section (<= 80 chars)' },
              },
              required: %w[generated_stable_id after_stable_id parent_stable_id libelle],
            },
            justification: { type: 'string', description: "Justification concise en 1-2 phrases : 1) Indique quels champs (citer leurs libellés) sont regroupés et pourquoi ce regroupement aide l'usager. 2) Précise après quel champ la section est placée (ou 'en première position' si after_stable_id est null). Exemple : 'Regroupement des 4 champs relatifs à l'entreprise (Nom entreprise, SIRET, Adresse siège, Téléphone entreprise) sous une section dédiée pour clarifier cette partie du formulaire. Section placée après le champ Email.'" },
          },
          additionalProperties: false,
        },
      },
    }.freeze

    def system_prompt(procedure)
      <<~TXT
        Tu es un assistant expert en simplification administrative française. Ton objectif : améliorer la structure des formulaires pour faciliter le parcours usager, en ajoutant des sections selon les principes de logique et de présentation.

        IMPORTANT : Une section contient des champs : dans le schéma, `section_id` désigne la header_section qui contient un champ. La header_section que tu ajoutes prend les champs qui la suivent là où elle est placée, jusqu'à la prochaine header_section.

        ## PRINCIPE CRITIQUE DE POSITIONNEMENT :

        Le paramètre `after_stable_id` désigne le champ APRÈS LEQUEL tu veux insérer la section, parmi ceux qui ont le même `section_id`.
        - Si tu veux que ta section apparaisse AVANT le champ X, tu dois utiliser le stable_id du champ qui PRÉCÈDE X avec le même `section_id` que X
        - Si X est le premier champ de sa section : after_stable_id: null et parent_stable_id: le `section_id` de X
        - Une header_section en after_stable_id place la section APRÈS tous les champs qu'elle contient, jamais juste après son titre
        - after_stable_id: null et parent_stable_id: null = placer la section en TOUTE PREMIÈRE position
        - Exemple : pour insérer une section avant le champ en position 3, utilise le stable_id du champ en position 2 s'il a le même `section_id`

        ## EXEMPLES DE RAISONNEMENT CORRECT :

        **Exemple 1 : Groupe trop petit (REJETÉ)**

        Schéma initial :
        [
          { stable_id: 10, libelle: "Email", position: 0, type: "email" },
          { stable_id: 20, libelle: "Nom", position: 1, type: "text" },
          { stable_id: 30, libelle: "Prénom", position: 2, type: "text" },
          { stable_id: 40, libelle: "Montant demandé", position: 3, type: "decimal_number" }
        ]

        Analyse :
        - Les champs Nom/Prénom forment un groupe cohérent "Identité"
        - Ce groupe contient 2 champs (positions 1, 2)
        - PROBLÈME : 2 champs < 3 minimum requis
        - DÉCISION : Je ne propose PAS cette section

        **Exemple 2 : Regroupement valide (ACCEPTÉ)**

        Schéma initial :
        [
          { stable_id: 10, libelle: "Email", position: 0, type: "email" },
          { stable_id: 20, libelle: "Nom entreprise", position: 1, type: "text" },
          { stable_id: 30, libelle: "SIRET", position: 2, type: "siret" },
          { stable_id: 40, libelle: "Adresse siège", position: 3, type: "address" },
          { stable_id: 50, libelle: "Téléphone entreprise", position: 4, type: "phone" },
          { stable_id: 60, libelle: "Montant demandé", position: 5, type: "decimal_number" }
        ]

        Analyse :
        - Les champs Nom/SIRET/Adresse/Téléphone forment un groupe "Informations entreprise"
        - Ce groupe contient 4 champs (positions 1, 2, 3, 4)
        - Aucun champ n'a de display_condition
        - Le premier champ du groupe est en position 1 (Nom entreprise)
        - Le champ qui PRÉCÈDE cette position est Email (stable_id: 10, position: 0)
        - DONC : after_stable_id = 10

        Tool call correct :
        {
          "add": {
            "generated_stable_id": -1,
            "after_stable_id": 10,
            "libelle": "Informations sur l'entreprise",
            "parent_stable_id": null
          },
          "justification": "Regroupement des 4 champs relatifs à l'entreprise (Nom entreprise, SIRET, Adresse siège, Téléphone entreprise) sous une section dédiée pour clarifier cette partie du formulaire. Section placée après le champ Email."
        }

        Structure résultante :
        [Email] → [SECTION "Informations sur l'entreprise"] → [Nom entreprise] → [SIRET] → [Adresse siège] → [Téléphone entreprise] → [Montant demandé]

        **Exemple 3 : Section en début de formulaire (ACCEPTÉ)**

        Schéma initial :
        [
          { stable_id: 10, libelle: "Nom", position: 0, type: "text" },
          { stable_id: 20, libelle: "Prénom", position: 1, type: "text" },
          { stable_id: 30, libelle: "Date de naissance", position: 2, type: "date" },
          { stable_id: 40, libelle: "Nationalité", position: 3, type: "pays" },
          { stable_id: 50, libelle: "Adresse", position: 4, type: "address" }
        ]

        Analyse :
        - Les 4 premiers champs forment un groupe "Identité"
        - Ce groupe contient 4 champs
        - Je veux placer la section AVANT le premier champ (position 0)
        - Il n'y a AUCUN champ avant la position 0
        - DONC : after_stable_id = null

        Tool call correct :
        {
          "add": {
            "generated_stable_id": -1,
            "after_stable_id": null,
            "libelle": "Votre identité",
            "parent_stable_id": null
          },
          "justification": "Regroupement des 4 champs d'identité (Nom, Prénom, Date de naissance, Nationalité) sous une section en début de formulaire. Section placée en première position."
        }

        Structure résultante :
        [SECTION "Votre identité"] → [Nom] → [Prénom] → [Date de naissance] → [Nationalité] → [Adresse]

        **Exemple 4 : Section déjà existante (REJETÉ)**

        Schéma initial :
        [
          { stable_id: 5, libelle: "Email", position: 0, type: "email" },
          { stable_id: 10, libelle: "Informations sur l'entreprise", position: 1, type: "header_section", header_section_level: 1 },
          { stable_id: 20, libelle: "Nom entreprise", position: 2, type: "text", section_id: 10 },
          { stable_id: 30, libelle: "SIRET", position: 3, type: "siret", section_id: 10 },
          { stable_id: 40, libelle: "Adresse siège", position: 4, type: "address", section_id: 10 },
          { stable_id: 50, libelle: "Téléphone entreprise", position: 5, type: "phone", section_id: 10 }
        ]

        Analyse :
        - Les champs Nom/SIRET/Adresse/Téléphone forment un groupe cohérent
        - Ce groupe contient 4 champs
        - MAIS : Une header_section "Informations sur l'entreprise" existe DÉJÀ (stable_id: 10, position: 1)
        - Cette section contient déjà ces champs (section_id: 10)
        - DÉCISION : Je ne propose PAS de nouvelle section (éviter la redondance)

        Rappel : Vérifie toujours si une section appropriée existe déjà avant d'en proposer une nouvelle.

        **Exemple 5 : Sous-section en début de section (ACCEPTÉ)**

        Schéma initial :
        [
          { stable_id: 10, libelle: "Votre projet", position: 0, type: "header_section", header_section_level: 1 },
          { stable_id: 20, libelle: "Montant demandé", position: 1, type: "decimal_number", section_id: 10 },
          { stable_id: 30, libelle: "Montant des autres aides", position: 2, type: "decimal_number", section_id: 10 },
          { stable_id: 40, libelle: "Budget total", position: 3, type: "decimal_number", section_id: 10 },
          { stable_id: 50, libelle: "Calendrier du projet", position: 4, type: "header_section", header_section_level: 2, section_id: 10 },
          { stable_id: 60, libelle: "Date de début", position: 5, type: "date", section_id: 50 },
          { stable_id: 70, libelle: "Date de fin", position: 6, type: "date", section_id: 50 }
        ]

        Analyse :
        - Les champs Montant demandé/Montant des autres aides/Budget total forment un groupe "Budget du projet", au même niveau que "Calendrier du projet"
        - Le premier champ du groupe (Montant demandé) est le premier de sa section (section_id: 10)
        - Aucun champ ne le précède dans cette section : after_stable_id: 10 placerait la section APRÈS tout ce que contient "Votre projet"
        - DONC : after_stable_id = null et parent_stable_id = 10

        Tool call correct :
        {
          "add": {
            "generated_stable_id": -1,
            "after_stable_id": null,
            "libelle": "Budget du projet",
            "parent_stable_id": 10
          },
          "justification": "Regroupement des 3 champs de budget (Montant demandé, Montant des autres aides, Budget total) sous une sous-section. Section placée en première position de la section Votre projet."
        }

        Structure résultante :
        [SECTION "Votre projet"] → [SOUS-SECTION "Budget du projet"] → [Montant demandé] → [Montant des autres aides] → [Budget total] → [SOUS-SECTION "Calendrier du projet"] → [Date de début] → [Date de fin]

        ## MÉTHODOLOGIE OBLIGATOIRE EN 2 PHASES :

        PHASE 1 OBLIGATOIRE - AUDIT (mental, pas de tool call) :
        Pour chaque groupe potentiel de champs :
        1. Liste les stable_id des champs du groupe
        2. Compte le nombre de champs (minimum 3 requis)
        3. Vérifie qu'aucun champ n'a de display_condition
        4. Vérifie qu'une header_section appropriée n'existe PAS déjà pour ce groupe
        5. Identifie la position du premier champ du groupe
        6. Trouve le stable_id du champ qui PRÉCÈDE cette position avec le même section_id (sera ton after_stable_id) ; si le premier champ du groupe est le premier de sa section, after_stable_id est null et parent_stable_id est son section_id

        PHASE 2 - AMELIORATION (avec tool calls) :
        Pour chaque groupe validé, utilise UN tool call avec l'outil #{TOOL_DEFINITION.dig(:function, :name)} pour proposer l'ajout de la header_section.
      TXT
    end

    def reject_schema_to_llm_scope
      [
        :mandatory,
        :total_choices,
        :sample_choices,
        :choices_dynamic,
        :options,
      ].freeze
    end

    # important: la position des champ existant est connue
    # quand on ajoute un champ, notre API interne le position en fonction du champ qui le prédède
    # il y a donc un non alignment dans nos interface a ce moment la
    # https://www.modernisation.gouv.fr/files/2021-06/avec_logique_linformation_tu_organiseras_com.pdf
    # https://www.modernisation.gouv.fr/files/Campus-de-la-transformation/Guide-kit-formulaire.pdf
    # https://www.modernisation.gouv.fr/campus-de-la-transformation-publique/catalogue-de-ressources/outil/simplifier-les-documents
    #  - https://www.modernisation.gouv.fr/files/2021-06/aller_a_lessentiel_com.pdf
    #  - https://www.modernisation.gouv.fr/files/2021-06/des_mots_simples_tu_utiliseras_com.pdf
    #  - https://www.modernisation.gouv.fr/files/2021-06/avec_logique_linformation_tu_organiseras_com.pdf
    #  - https://www.modernisation.gouv.fr/files/2021-06/lusager_tu_considereras_com.pdf
    #  - https://www.modernisation.gouv.fr/files/2021-06/la_presentation_tu_soigneras_com.pdf
    def rules_prompt
      <<~TXT
        Applique ces règles PAR ORDRE DE PRIORITÉ.

        ═══════════════════════════════════════════════════════════════
        PRIORITÉ 1 : CONTRAINTES TECHNIQUES (bloquant si non respecté)
        ═══════════════════════════════════════════════════════════════

        1.1. Taille minimale des sections
            - Chaque header_section doit regrouper AU MINIMUM 3 champs
            - Compter UNIQUEMENT les champs toujours visibles (sans display_condition)
            - Si un groupe contient < 3 champs → ne propose RIEN pour ce groupe
              KO Groupe de 2 champs [Nom, Prénom]
              OK Groupe de 3 champs [Nom, Prénom, Email]
              OK Groupe de 4+ champs [Nom, Prénom, Email, Téléphone]

        1.2. Champs conditionnels
            - JAMAIS de header_section juste avant un champ avec display_condition
            - Raison : le titre apparaîtrait seul si la condition est fausse (bug UX grave)
            - Vérifier que les 3+ premiers champs après la section n'ont PAS de display_condition
              KO Section "Coordonnées" → [Adresse (conditionnel)]
              OK Section "Coordonnées" → [Adresse, Ville, Code postal]

        1.3. Sections existantes
            - JAMAIS ajouter une section si une header_section appropriée existe déjà pour le même groupe de champs
            - Vérifier le schéma pour identifier les sections déjà présentes
              KO Section "Identité" existe déjà → ne pas proposer une nouvelle section "Vos informations personnelles" pour les mêmes champs
              OK Aucune section n'existe pour ce groupe de champs → proposer une section pertinente

        1.4. Unicité des positions
            - Chaque after_stable_id que tu proposes doit être UNIQUE dans tes propositions
            - JAMAIS proposer 2 sections avec le même after_stable_id, ni 2 sections en premier dans la même section (même parent_stable_id avec after_stable_id: null)
              KO Deux sections avec after_stable_id: 10
              OK Section A avec after_stable_id: 10, Section B avec after_stable_id: 20

        >> Si UNE SEULE contrainte PRIORITÉ 1 ne peut être respectée : ABANDONNE ce groupe.

        ═══════════════════════════════════════════════════════════════
        PRIORITÉ 2 : COHÉRENCE STRUCTURELLE (éviter les incohérences)
        ═══════════════════════════════════════════════════════════════

        2.1. Pertinence et utilité
            - Chaque section doit apporter une clarification réelle à l'usager
            - JAMAIS de sections redondantes avec les libellés des champs
              KO Section "Informations" → [Nom, Prénom, Email] (trop vague)
              OK Section "Votre identité" → [Nom, Prénom, Date naissance]

        2.2. Cohérence hiérarchique
            - Les sections s'imbriquent sur 3 niveaux au plus
            - Une sous-section se place dans une section : après un champ de cette section (after_stable_id), ou en premier dans celle-ci (parent_stable_id)
              KO Sous-section "Détails" dans une section de niveau 3
              OK Section "Projet" → sous-section "Budget du projet" placée après un champ de "Projet"

        ═══════════════════════════════════════════════════════════════
        PRIORITÉ 3 : QUALITÉ RÉDACTIONNELLE (bonnes pratiques UX)
        ═══════════════════════════════════════════════════════════════

        3.1. Libellés des sections
            - Concis : idéalement <= 60 caractères, maximum 80 caractères
            - Langage simple et accessible (niveau RGAA)
              KO "Données d'identification utilisateur"
              OK "Vos coordonnées"

        3.2. Regroupements cohérents
            - Regrouper les champs thématiquement liés
              OK Pour une demande de subvention : Section "Votre structure" regroupant [Nom, SIRET, Adresse, Téléphone]
              OK Pour un dossier médical : Section "Antécédents médicaux" regroupant les champs santé

        ═══════════════════════════════════════════════════════════════
        OUTIL À UTILISER
        ═══════════════════════════════════════════════════════════════

        Utilise l'outil #{TOOL_DEFINITION.dig(:function, :name)} pour chaque amélioration.
        Génère des generated_stable_id négatifs uniques (e.g., -1, -2, -3).

        >> RAPPEL CRITIQUE : Il vaut mieux ne faire AUCUNE proposition que de proposer quelque chose violant PRIORITÉ 1.
      TXT
    end

    def build_item(args, tdc_index: {})
      return nil unless args['add']

      data = args['add'].is_a?(Hash) ? args['add'].dup : {}
      payload = data.compact
      payload['type_champ'] = 'header_section'

      {
        op_kind: 'add',
        stable_id: nil,
        payload: payload,
        verify_status: 'review',
        justification: args['justification'].to_s.presence,
      }
    end
  end
end
