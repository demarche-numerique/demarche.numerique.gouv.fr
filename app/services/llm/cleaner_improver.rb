# frozen_string_literal: true

module LLM
  class CleanerImprover < BaseImprover
    TOOL_DEFINITION = {
      type: 'function',
      function: {
        name: LLMRuleSuggestion.rules.fetch('cleaner'),
        description: 'Propose la suppression d\'un champ redondant avec un autre champ du formulaire. N\'utilise cet outil QUE si tu as identifié une VRAIE redondance (même information demandée deux fois).',
        parameters: {
          type: 'object',
          properties: {
            destroy: {
              type: 'object',
              description: 'Suppression d\'un champ redondant',
              properties: {
                stable_id: { type: 'integer', description: 'Identifiant du champ redondant à supprimer' },
                source_stable_id: { type: 'integer', description: 'Identifiant du champ qui fournit déjà cette même information (OBLIGATOIRE). Ce champ doit RÉELLEMENT fournir l\'information (champ spécialisé ou synonyme exact). ATTENTION : Un champ "Nom" NE fournit PAS un "Email" ou un "Prénom" !' },
              },
              required: %w[stable_id source_stable_id],
            },
            justification: { type: 'string', description: 'Phrase affirmative expliquant pourquoi ces deux champs demandent la MÊME information. Format: "Le champ [source] fournit déjà [information], rendant le champ [à supprimer] redondant." Exemple: "Le champ SIRET fournit déjà la raison sociale, rendant le champ Raison sociale redondant."' },
          },
          additionalProperties: false,
        },
      },
    }.freeze

    def system_prompt(procedure)
      <<~TXT
        Tu es un assistant chargé d'identifier les champs redondants dans un formulaire administratif français.

        MÉTHODOLOGIE OBLIGATOIRE EN 3 ÉTAPES :

        ÉTAPE 1 - AUDIT COMPLET (mental, sans tool call) :
        Parcours TOUS les champs du schéma et identifie ceux qui sont redondants.
        Pour chaque champ : pose-toi la question "Est-ce qu'un autre champ de la MÊME section fournit déjà cette MÊME donnée exacte ?"

        Exemples de questions à te poser (avec validation) :
        - "Est-ce que le SIRET fournit déjà la raison sociale ?"
          → Vérification : Le SIRET est un champ spécialisé qui collecte automatiquement la raison sociale
          → Réponse : OUI → redondance ✅

        - "Est-ce que le champ Nom fournit déjà l'email ?"
          → Vérification : Le Nom est un champ text, l'email est un champ email, ce sont deux types d'information différents
          → Réponse : NON → pas de redondance ❌

        - "Est-ce que le champ Nom fournit déjà le prénom ?"
          → Vérification : Nom et Prénom sont deux parties différentes d'une identité
          → Réponse : NON → pas de redondance ❌

        - "Est-ce que l'adresse fournit déjà le code postal ?"
          → Vérification : L'adresse est un champ spécialisé qui collecte automatiquement le code postal
          → Réponse : OUI → redondance ✅

        ÉTAPE 2 - DÉCISION (mental, sans tool call) :
        Pour chaque champ potentiellement redondant identifié en ÉTAPE 1 :
        - Identifie le stable_id du champ source (celui qui fournit déjà l'information)
        - Si tu ne peux pas identifier de champ source précis → ce n'est PAS une redondance

        Établis la liste finale : paires (champ_redondant, champ_source)
        Si AUCUNE paire n'a été identifiée → STOP ici, réponds "Aucun champ redondant identifié"

        ÉTAPE 3 - SUPPRESSION (avec tool calls) :
        UNIQUEMENT si des paires ont été identifiées en ÉTAPE 2 :
        Pour CHAQUE paire, génère UN tool call #{TOOL_DEFINITION.dig(:function, :name)} avec :
        - stable_id : le champ redondant à supprimer
        - source_stable_id : le champ qui fournit déjà cette information

        RÈGLE ABSOLUE :
        - N'appelle l'outil QUE pour supprimer un champ réellement redondant
        - Si tu n'es pas certain à 100% → ne supprime PAS
      TXT
    end

    def rules_prompt
      <<~TXT
        #{section_explanation}

        ═══════════════════════════════════════════════════════════════
        RÈGLES D'IDENTIFICATION DES CHAMPS REDONDANTS
        ═══════════════════════════════════════════════════════════════

        DÉFINITION DE "FOURNIR" UNE INFORMATION :
        Un champ A "fournit" une information B si et seulement si :
        1. Le champ A est un CHAMP SPÉCIALISÉ qui collecte automatiquement l'information B
           Exemples : SIRET fournit la raison sociale, Address fournit le code postal
        2. OU les deux champs demandent EXACTEMENT la même chose avec des libellés synonymes
           Exemple : "Nom de l'entreprise" et "Raison sociale"

        CE QUI NE "FOURNIT" PAS :
        ✗ Un champ "Nom" NE fournit PAS le "Prénom" (deux parties différentes de l'identité)
        ✗ Un champ "Nom" NE fournit PAS l'"Email" (deux types d'information totalement différents)
        ✗ Un champ "Prénom" NE fournit PAS l'"Email"
        ✗ Un champ "Téléphone" NE fournit PAS l'"Email"
        ✗ En général : un champ de type "text" NE fournit PAS un champ de type différent (email, phone, etc.)

        DÉFINITION DE "REDONDANCE" :
        Deux champs sont redondants si et seulement si un champ FOURNIT (au sens ci-dessus) l'information de l'autre.

        Exemples de VRAIES redondances :
        - SIRET (type: siret) fournit "Raison sociale" → un champ "Raison sociale" (type: text) est redondant
        - Address (type: address) fournit "Code postal" → un champ "Code postal" (type: text) est redondant
        - "Nom de l'entreprise" (type: text) ET "Raison sociale" (type: text) → synonymes, redondants

        Exemples de NON-redondances (informations COMPLÉMENTAIRES) :
        - Nom (type: text) ET Prénom (type: text) → deux parties DIFFÉRENTES d'une identité
        - Nom (type: text) ET Email (type: email) → deux types d'information DIFFÉRENTS
        - Prénom (type: text) ET Email (type: email) → deux types d'information DIFFÉRENTS
        - Téléphone (type: phone) ET Email (type: email) → deux types d'information DIFFÉRENTS

        UN CHAMP EST REDONDANT SI ET SEULEMENT SI :
        ✓ Un autre champ de la MÊME section fournit déjà cette MÊME information exacte
        ✓ Les deux champs demandent la MÊME donnée (pas juste "concernent la même personne")
        ✓ Il n'y a AUCUNE nuance distinguant les deux champs

        CONTRAINTES BLOQUANTES (ne jamais supprimer si) :
        ✗ Le champ a une display_condition
        ✗ Les champs sont dans des sections différentes
        ✗ Il existe une nuance sémantique entre les champs (ex: "siège" vs "correspondance", "fixe" vs "portable")

        ATTENTION AUX FAUX POSITIFS (informations complémentaires, PAS redondantes) :

        Identité d'une personne (JAMAIS redondantes entre elles) :
        - "Nom" ≠ "Prénom" ≠ "Email" ≠ "Téléphone" ≠ "Adresse"
        - Ces 5 champs sont TOUJOURS distincts et complémentaires
        - Même s'ils concernent la même personne, ce ne sont PAS des redondances !

        Nuances sémantiques :
        - "Adresse du siège" ≠ "Adresse de correspondance"
        - "Email professionnel" ≠ "Email personnel"
        - "Téléphone fixe" ≠ "Téléphone portable"

        RÈGLE D'OR : Si tu peux remplir les deux champs avec des valeurs DIFFÉRENTES, alors ils ne sont PAS redondants !

        ═══════════════════════════════════════════════════════════════
        TYPES DE CHAMPS SPÉCIALISÉS (référence)
        ═══════════════════════════════════════════════════════════════

        Localisation (avec auto-complétion et données enrichies) :
        - address : Adresse postale complète avec autocomplete. Fournit : commune, code postal, département, région, pays, code INSEE de la commune.
        - communes : Sélection d'une commune française. Fournit : nom, code postal, département, code INSEE

        Identification d'entités :
        - siret : Numéro SIRET d'une entreprise. Fournit automatiquement et exclusivement : raison sociale, SIREN, nom commercial, forme juridique, code et libellé NAF, adresse normalisée de l'établissement, adresse normalisée du siège social, N° TVA intracommunautaire, capital social, code effectif, date de création, état administratif.
        - rna : Répertoire National des Associations. Fournit : nom de l'association, titre et objet de l'association, adresse normalisée, état administratif
        - rnf : Répertoire National des Fondations. Fournit : nom, adresse normalisée, état administratif
        - annuaire_education : Identifiant d'un établissement scolaire. Fournit : nom de l'établissement, adresse normalisée, académie, nature de l'établissement, téléphone, email, site internet.
        - address : numéro, nom de la voie, code postal, nom de la commune, code INSEE de la commune, département de la commune, région de la commune, pays

        ═══════════════════════════════════════════════════════════════
        EXEMPLES DÉTAILLÉS
        ═══════════════════════════════════════════════════════════════

        **Exemple 1**

        Schéma initial :
        [
          { stable_id: 10, libelle: "Informations entreprise", position: 0, type: "header_section" },
          { stable_id: 20, libelle: "SIRET", position: 1, type: "siret" },
          { stable_id: 30, libelle: "Raison sociale", position: 2, type: "text" },
          { stable_id: 40, libelle: "Adresse du siège social", position: 3, type: "text" }
        ]

        Analyse :
        - Le SIRET (position 1) fournit automatiquement raison sociale ET adresse du siège
        - Les champs Raison sociale et Adresse sont dans la même section "Informations entreprise"
        - Même contexte (l'entreprise), pas de nuance (pas "adresse de correspondance")
        - DÉCISION : Supprimer les champs 30 et 40 (redondance avérée)

        Tool calls corrects :
        {
          "destroy": { "stable_id": 30, "source_stable_id": 20 },
          "justification": "Le champ SIRET (stable_id: 20) fournit déjà la raison sociale, rendant le champ Raison sociale (stable_id: 30) redondant."
        }
        {
          "destroy": { "stable_id": 40, "source_stable_id": 20 },
          "justification": "Le champ SIRET (stable_id: 20) fournit déjà l'adresse du siège social, rendant le champ Adresse du siège social (stable_id: 40) redondant."
        }

        **Exemple 2 : Sections différentes (REJETÉ)**

        Schéma initial :
        [
          { stable_id: 5, libelle: "Votre identité", position: 0, type: "header_section" },
          { stable_id: 10, libelle: "Adresse de résidence", position: 1, type: "address" },
          { stable_id: 20, libelle: "Lieu de naissance", position: 2, type: "header_section" },
          { stable_id: 30, libelle: "Commune de naissance", position: 3, type: "communes" }
        ]

        Analyse section "Votre identité" :
        - Champ "Adresse de résidence" (stable_id: 10) → aucune redondance dans cette section

        Analyse section "Lieu de naissance" :
        - Champ "Commune de naissance" (stable_id: 30)
        - L'adresse de résidence (stable_id: 10) fournit une commune MAIS elle est dans une section différente
        - DÉCISION : NE PAS supprimer (sections différentes)

        **Exemple 3 : Informations complémentaires d'identité (REJETÉ)**

        Schéma initial :
        [
          { stable_id: 10, libelle: "Représentant légal", position: 0, type: "header_section" },
          { stable_id: 20, libelle: "Nom", position: 1, type: "text" },
          { stable_id: 30, libelle: "Prénom", position: 2, type: "text" },
          { stable_id: 40, libelle: "Adresse électronique", position: 3, type: "email" }
        ]

        Analyse section "Représentant légal" :
        - Champ "Nom" (stable_id: 20) → demande le nom de famille
        - Champ "Prénom" (stable_id: 30) → demande le prénom
        - Champ "Adresse électronique" (stable_id: 40) → demande l'email
        - Ces trois informations sont DIFFÉRENTES (on peut avoir Nom="Dupont", Prénom="Marie", Email="marie.dupont@example.com")
        - Aucun champ ne fournit l'information des autres
        - DÉCISION : NE PAS supprimer (trois informations complémentaires, pas redondantes)

        Réponse correcte : "Aucun champ redondant identifié"
        (PAS de tool call)

        POURQUOI PAS de tool call ?
        - Le champ Nom NE fournit PAS le Prénom → on ne peut pas mettre source_stable_id = 20
        - Le champ Nom NE fournit PAS l'Email → on ne peut pas mettre source_stable_id = 20
        - Le champ Prénom NE fournit PAS l'Email → on ne peut pas mettre source_stable_id = 30
        - Aucun champ ne fournit l'information des autres → impossible de trouver un source_stable_id valide

        **Exemple 4 : ERREUR FRÉQUENTE - Source inventée (INVALIDE)**

        Schéma initial :
        [
          { stable_id: 10, libelle: "Représentant légal", position: 0, type: "header_section" },
          { stable_id: 20, libelle: "Nom", position: 1, type: "text" },
          { stable_id: 30, libelle: "Prénom", position: 2, type: "text" },
          { stable_id: 40, libelle: "Adresse électronique", position: 3, type: "email" }
        ]

        ❌ MAUVAIS tool call (INVALIDE) :
        {
          "destroy": { "stable_id": 40, "source_stable_id": 20 },
          "justification": "Le champ Nom (stable_id: 20) fournit déjà l'adresse électronique..."
        }

        POURQUOI C'EST INVALIDE :
        - Le champ "Nom" (type: text) NE fournit PAS l'adresse électronique !
        - Un nom et un email sont deux informations COMPLÈTEMENT DIFFÉRENTES
        - On ne peut pas remplir un email avec un nom
        - RÈGLE : Ne jamais inventer de source_stable_id si le champ ne fournit pas réellement l'information

        ✅ BONNE réponse : "Aucun champ redondant identifié" (sans tool call)

        **Exemple 5 : Vraie redondance avec champ spécialisé (ACCEPTÉ)**

        Schéma initial :
        [
          { stable_id: 10, libelle: "Adresse de l'entreprise", position: 0, type: "header_section" },
          { stable_id: 20, libelle: "Adresse complète", position: 1, type: "address" },
          { stable_id: 30, libelle: "Code postal", position: 2, type: "text" }
        ]

        Analyse section "Adresse de l'entreprise" :
        - Champ "Adresse complète" (stable_id: 20, type: address) fournit automatiquement le code postal
        - Champ "Code postal" (stable_id: 30) → REDONDANT car l'address fournit déjà cette info
        - DÉCISION : Supprimer le champ 30

        Tool call :
        {
          "destroy": { "stable_id": 30, "source_stable_id": 20 },
          "justification": "Le champ Adresse complète (stable_id: 20) fournit déjà le code postal, rendant le champ Code postal (stable_id: 30) redondant."
        }


        ═══════════════════════════════════════════════════════════════
        OUTIL À UTILISER
        ═══════════════════════════════════════════════════════════════

        QUAND UTILISER L'OUTIL :
        - Utilise l'outil #{TOOL_DEFINITION.dig(:function, :name)} UNIQUEMENT pour supprimer un champ réellement redondant
        - Un appel par champ à supprimer
        - OBLIGATOIRE : Tu dois fournir à la fois le stable_id du champ redondant ET le source_stable_id du champ qui fournit déjà l'information
        - Si tu ne peux pas identifier de source_stable_id → c'est qu'il n'y a PAS de redondance → NE PAS appeler l'outil
        - Si aucun champ redondant : réponds "Aucun champ redondant identifié" SANS appeler l'outil

        >> RAPPEL CRITIQUE :
        - N'appelle l'outil QUE si tu as identifié une VRAIE redondance (= MÊME information demandée deux fois)
        - Si aucune redondance trouvée : réponds "Aucun champ redondant identifié" SANS tool call
        - Si tu hésites : NE PAS appeler l'outil

        CAS FRÉQUENTS QUI NE SONT JAMAIS DES REDONDANCES :
        - Nom, Prénom, Email, Téléphone, Adresse → 5 champs DISTINCTS, jamais redondants entre eux
        - Même s'ils sont dans la même section "Représentant légal" ou "Contact"
        - Ce sont des informations COMPLÉMENTAIRES, pas redondantes !

        TEST SIMPLE : Pose-toi ces questions DANS L'ORDRE :

        1. "Quel champ pourrait fournir cette information ?"
        2. "Est-ce que ce champ FOURNIT RÉELLEMENT cette information ?" (voir définition de "FOURNIR" ci-dessus)

        Exemples :
        - Pour "Raison sociale" :
          1. Quel champ ? → Le SIRET (stable_id: 20)
          2. Le SIRET fournit-il la raison sociale ? → OUI (champ spécialisé) ✅
          → source_stable_id = 20, appeler l'outil

        - Pour "Email" dans une section avec Nom/Prénom :
          1. Quel champ ? → Peut-être le Nom (stable_id: 20) ?
          2. Le Nom fournit-il l'email ? → NON ! Un nom n'est pas un email ❌
          → PAS de source valide → NE PAS appeler l'outil

        - Pour "Prénom" dans une section avec Nom :
          1. Quel champ ? → Le Nom (stable_id: 20) ?
          2. Le Nom fournit-il le prénom ? → NON ! Nom et Prénom sont deux parties différentes ❌
          → PAS de source valide → NE PAS appeler l'outil

        PREUVE OBLIGATOIRE - VÉRIFICATION DU source_stable_id :
        Avant d'appeler l'outil, vérifie que le champ source FOURNIT RÉELLEMENT l'information :

        ✅ VALIDE : "Le champ SIRET (type: siret, stable_id: 20) fournit la raison sociale"
           → Le SIRET collecte automatiquement la raison sociale → source_stable_id = 20 OK

        ❌ INVALIDE : "Le champ Nom (type: text, stable_id: 20) fournit l'adresse électronique"
           → Un Nom NE fournit PAS un email → source_stable_id = 20 FAUX → NE PAS appeler l'outil !

        ❌ INVALIDE : "Le champ Nom (type: text, stable_id: 20) fournit le prénom"
           → Un Nom NE fournit PAS un prénom (deux parties différentes) → NE PAS appeler l'outil !

        RÈGLES DE VALIDATION :
        - Si le champ source n'est PAS un champ spécialisé (siret, address, rna, etc.) → vérifier que les libellés sont synonymes
        - Si les types sont différents (text vs email, text vs phone) → PAS de redondance → NE PAS appeler l'outil
        - Si tu inventes une source qui ne fournit pas réellement l'info → l'appel sera INVALIDE

        Si ta justification contient "aucun doublon", "pas de redondance", "information distincte", ou "complémentaire" → NE PAS appeler l'outil !
      TXT
    end

    def build_item(args, tdc_index: {})
      build_destroy_item(args, tdc_index:) if args['destroy']
    end

    private

    def build_destroy_item(args, tdc_index:)
      data = args['destroy']
      stable_id = data.is_a?(Hash) ? data['stable_id'] : data

      return if stable_id.nil?
      return if used_as_condition_source?(stable_id, tdc_index)

      {
        op_kind: 'destroy',
        stable_id:,
        payload: { 'stable_id' => stable_id },
        verify_status: 'pending',
        justification: args['justification'].presence,
      }
    end

    def used_as_condition_source?(stable_id, tdc_index)
      tdc_index.values.any? do |tdc|
        tdc.condition&.sources&.include?(stable_id)
      end
    end

    def before_schema(procedure)
      if procedure.for_individual?
        <<~TEXT.strip
          - Civilité (M./Mme)
          - Nom
          - Prénom
          - Email
        TEXT
      elsif procedure.for_personne_morale?
        <<~TEXT.strip
          - Email
          - SIRET

          Le SIRET a permis de récupérer automatiquement ces informations sur l'entreprise/établissement :
          - SIREN
          - Raison sociale (ou Nom + Prénom pour les entrepreneurs individuels)
          - Nom commercial
          - Enseigne
          - Forme juridique (libellé et code)
          - Code NAF et libellé d'activité
          - N° TVA intracommunautaire
          - Capital social
          - Date de création
          - État administratif (actif/fermé)
          - Code effectif entreprise
          - SIRET du siège social
          - Adresse normalisée complète de l'établissement : numéro et nom de voie, complément d'adresse, code postal, localité (commune), code INSEE de la localité
        TEXT
      else
        ''
      end
    end
  end
end
