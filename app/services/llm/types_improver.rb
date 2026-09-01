# frozen_string_literal: true

module LLM
  class TypesImprover < BaseImprover
    TOOL_DEFINITION = {
      type: 'function',
      function: {
        name: LLMRuleSuggestion.rules.fetch('improve_types'),
        description: 'Propose un changement de type de champ pour une meilleure UX pour l\'usager et des données consolidées pour les instructeurs',
        parameters: {
          type: 'object',
          properties: {
            update: {
              type: 'object',
              description: 'Changement de type',
              properties: {
                stable_id: { type: 'integer', description: 'Identifiant du champ à modifier.' },
                type_champ: { type: 'string', description: 'Nouveau type du champ. Répéter le type actuel si seule la nature change.' },
                nature: {
                  type: 'string',
                  description: <<~DESC.squish,
                    Nature de la pièce, uniquement pour type_champ "piece_justificative".
                    Une des valeurs : non_specifie, titre_identite, rib, justificatif_domicile, avis_impot.
                  DESC
                },
                options: {
                  type: 'object',
                  description: <<~DESC.squish,
                    Options spécifiques au type de champ.
                    Pour formatted, at least one of: letters_accepted (boolean), numbers_accepted (boolean), special_characters_accepted (boolean), min_character_length (integer), max_character_length (integer).
                    Pour integer_number/decimal_number: positive_number (boolean), min_number (number), max_number (number).
                    Pour date/datetime: date_in_past (boolean), start_date (string ISO), end_date (string ISO).
                  DESC
                  additionalProperties: false,
                },
              },
              required: %w[stable_id type_champ],
            },
            justification: { type: 'string' },
          },
          additionalProperties: false,
        },
      },
    }.freeze

    def system_prompt(procedure)
      <<~TXT
        Tu es un assistant expert chargé d'améliorer les types de champs d'un formulaire administratif français.

        ## EXEMPLES DE RAISONNEMENT CORRECT :

        **Exemple 1 : Email mal typé (ACCEPTÉ)**

        Champ actuel :
        { stable_id: 10, libelle: "Adresse électronique", type: "text" }

        Analyse :
        - Le libellé indique clairement une adresse email
        - Type actuel : "text" (pas de validation)
        - Type recommandé : "email" (validation automatique du format)
        - GAIN : Validation côté client + meilleure UX mobile (clavier email)
        - DÉCISION : Proposer la transformation

        Tool call :
        {
          "update": { "stable_id": 10, "type_champ": "email" },
          "justification": "Validation automatique du format email et clavier adapté sur mobile."
        }

        **Exemple 2 : SIRET avec enrichissement (ACCEPTÉ)**

        Champ actuel :
        { stable_id: 20, libelle: "Numéro SIRET de l'entreprise", type: "text" }

        Analyse :
        - Demande explicite d'un SIRET
        - Type actuel : "text" (pas de validation, pas d'enrichissement)
        - Type recommandé : "siret" (validation + auto-remplissage raison sociale, adresse, etc.)
        - GAIN MAJEUR : Récupération automatique de 15+ données entreprise
        - DÉCISION : Proposer la transformation

        Tool call :
        {
          "update": { "stable_id": 20, "type_champ": "siret" },
          "justification": "Validation du format SIRET et récupération automatique des données entreprise (raison sociale, adresse, SIREN, etc.)."
        }

        **Exemple 3 : Sur-spécialisation (REJETÉ)**

        Champ actuel :
        { stable_id: 30, libelle: "Titre du projet", type: "text" }

        Analyse :
        - Demande un titre libre
        - Type actuel : "text" (approprié pour texte court libre)
        - Tentation : utiliser "formatted" pour limiter la longueur
        - PROBLÈME : "formatted" est pour des codes/identifiants normalisés, PAS pour du texte libre
        - Le champ n'a pas de format standardisé connu
        - DÉCISION : NE PAS proposer de transformation (type actuel correct)

        **Exemple 4 : Confusion pays/nationalité (REJETÉ)**

        Champ actuel :
        { stable_id: 40, libelle: "Pays de naissance", type: "text" }

        Analyse :
        - Demande le pays de naissance
        - Type actuel : "text"
        - Tentation : utiliser "pays"
        - PROBLÈME CRITIQUE : Le type "pays" ne contient QUE les pays ACTUELS
        - Les pays historiques (ex: URSS, Yougoslavie) sont absents
        - Pour les naissances, il faut inclure les pays historiques
        - DÉCISION : NE PAS proposer "pays" (risque de perte de données)

        **Exemple 5 : Consentement/Acceptation (ACCEPTÉ)**

        Champ actuel :
        { stable_id: 50, libelle: "J'atteste sur l'honneur l'exactitude des informations fournies", type: "text" }

        Analyse :
        - Le libellé est une attestation/consentement/engagement
        - Formulation commençant par "J'atteste", "J'accepte", "Je certifie", "Je m'engage"
        - Type actuel : "text" (l'usager doit saisir quelque chose, UX confuse)
        - Type recommandé : "checkbox" (case à cocher, interface claire et standard)
        - GAIN : UX claire pour les consentements, validation stricte (coché = consentement donné)
        - Si obligatoire, bloque la soumission si non coché
        - DÉCISION : Proposer la transformation

        Tool call :
        {
          "update": { "stable_id": 50, "type_champ": "checkbox" },
          "justification": "Interface standard de case à cocher pour les attestations et consentements, obligeant l'usager à confirmer explicitement son engagement."
        }

        **Exemple 6 : Lecture automatique d'un justificatif (ACCEPTÉ)**

        Champ actuel :
        { stable_id: 60, libelle: "Justificatif de domicile de moins de 3 mois", type: "piece_justificative", nature: "non_specifie" }

        Analyse :
        - Le libellé désigne UN document précis et connu : un justificatif de domicile
        - Nature actuelle : "non_specifie" (le fichier est stocké tel quel, aucune donnée exploitable)
        - Nature recommandée : "justificatif_domicile"
        - GAIN : si le document porte un cachet 2D-Doc, le bénéficiaire, l'adresse et la date d'émission sont extraits et transmis à l'instructeur
        - CONTREPARTIE ACCEPTABLE : le champ est limité à 1 fichier et aux formats document texte / scan, ce qui correspond à ce document
        - DÉCISION : Proposer le changement de nature (le type reste piece_justificative)

        Tool call :
        {
          "update": { "stable_id": 60, "type_champ": "piece_justificative", "nature": "justificatif_domicile" },
          "justification": "Lecture automatique du cachet 2D-Doc : le nom du bénéficiaire, l'adresse et la date d'émission sont transmis à l'instructeur."
        }

        **Exemple 7 : Pièce jointe générique (REJETÉ)**

        Champ actuel :
        { stable_id: 70, libelle: "Pièces complémentaires à votre demande", type: "piece_justificative", nature: "non_specifie" }

        Analyse :
        - Le libellé ne désigne AUCUN document précis : l'usager peut déposer n'importe quoi
        - Tentation : activer une nature pour bénéficier de la lecture automatique
        - PROBLÈME : activer une nature limite le champ à 1 SEUL fichier et aux formats document texte / scan
        - L'usager ne pourrait plus déposer plusieurs pièces → régression fonctionnelle
        - DÉCISION : NE PAS changer la nature

        ## MÉTHODOLOGIE OBLIGATOIRE EN 2 PHASES :

        PHASE 1 - AUDIT (mental, pas de tool call) :
        Pour CHAQUE champ, applique cette GRILLE DE DÉCISION :

        - OBLIGATOIRE : Lire ATTENTIVEMENT libellé ET description ENSEMBLE
          - Chercher indices de nuance : "si vous n'avez pas", "en attendant", "à défaut de", "temporaire", "alternatif"
          - Ne PAS transformer basé sur un simple mot-clé sans analyser le contexte complet

        - Le champ attend-il des DONNÉES STANDARDISÉES connues ?
          - email, phone, siret, iban, date, etc.
          - SI OUI : marquer pour transformation PRIORITÉ 1

        - Le champ est-il une piece_justificative attendant UN document à LECTURE AUTOMATIQUE ?
          - justificatif de domicile, RIB, avis d'imposition
          - SI OUI et nature == "non_specifie" : marquer pour changement de nature PRIORITÉ 1

        - Le champ bénéficierait-il d'AUTO-COMPLÉTION via référentiel ?
          - address, communes, départements, regions, rna, rnf, annuaire_education
          - SI OUI : marquer pour transformation PRIORITÉ 2

        - Le champ est-il un CONSENTEMENT, CHOIX BINAIRE ou parmi une liste ?
          - CONSENTEMENT (libellé commence par "J'atteste", "J'accepte", "Je certifie", "Je m'engage") → checkbox
          - Question binaire (Oui/Non, Avez-vous..., Êtes-vous...) → yes_no
          - Civilité → civilite
          - Choix unique/multiples → drop_down_list / multiple_drop_down_list
          - SI OUI : marquer pour transformation PRIORITÉ 3

        - GARDE-FOUS (bloquants) :
          - Type actuel déjà correct ? → NE PAS transformer
          - Risque de perte de données ? (ex: pays historiques) → NE PAS transformer
          - Texte libre sans format connu ? → NE PAS utiliser "formatted"
          - Nombre/code métier sans validation ? → NE PAS utiliser "integer_number"

        PHASE 2 - CORRECTIONS (avec tool calls) :
        Traiter les champs marqués PAR ORDRE DE PRIORITÉ (1 → 2 → 3).
        Générer UN tool call par transformation avec l'outil #{TOOL_DEFINITION.dig(:function, :name)}.
      TXT
    end

    def rules_prompt
      <<~TXT
        Applique ces règles PAR ORDRE DE PRIORITÉ.

        PRIORITÉ 1 : VALIDATION & ENRICHISSEMENT AUTOMATIQUE

        Ces transformations apportent le PLUS de valeur (validation + données enrichies).

        - email : Validation format email
          OK "Adresse électronique" (text) → email
          KO "Commentaires" (text) → garder text

        - phone : Validation formats FR et internationaux
          OK "Téléphone" (text) → phone
          KO "Numéro de dossier" (text) → garder text

        - iban : Validation format bancaire international
          OK "RIB" (text) → iban
          OK "IBAN pour virement" (text) → iban

        - siret : Validation + 15+ données entreprise auto-remplies
          OK "SIRET entreprise" (text) → siret
          OK "Numéro SIRET" (text) → siret

        - address : Validation + commune, code postal, département, région auto-remplis
          OK "Adresse complète" (text) → address
          OK "Adresse du siège" (text) → address
          KO "Commune uniquement" (text) → utiliser "communes" pas "address"

        - rna : RNA + données association
          OK "Numéro RNA" (text) → rna

        - rnf : Répertoire National des Fondations
          OK "Numéro RNF" (text) → rnf

        - annuaire_education : Identifiant établissement + données complètes
          OK "Établissement scolaire" (text) → annuaire_education

        - nature d'une piece_justificative : lecture automatique du document déposé
          Le type reste "piece_justificative", seule la "nature" change. Répète toujours "type_champ": "piece_justificative".
          Ne proposer QUE si la nature actuelle est "non_specifie" ET que le libellé désigne UN document précis.

          - justificatif_domicile : décode le cachet 2D-Doc → bénéficiaire, adresse, date d'émission
            OK "Justificatif de domicile" (nature non_specifie) → justificatif_domicile
            OK "Facture d'électricité, de gaz ou d'eau de moins de 3 mois" → justificatif_domicile
            OK "Quittance de loyer" → justificatif_domicile

          - rib : extrait titulaire, IBAN, BIC, nom de la banque
            OK "RIB" (nature non_specifie) → rib
            OK "Relevé d'identité bancaire" → rib

          - avis_impot : décode le cachet 2D-Doc → déclarants, revenu fiscal de référence, nombre de parts, référence d'avis
            OK "Avis d'imposition" (nature non_specifie) → avis_impot
            OK "Dernier avis d'impôt sur le revenu" → avis_impot

          KO "Pièces complémentaires" / "Autres documents" → NE PAS changer (aucun document précis)
          KO Champ où l'usager dépose plusieurs documents → NE PAS changer (la nature limite à 1 fichier)
          KO nature déjà renseignée (rib, justificatif_domicile, avis_impot, titre_identite) → NE PAS changer

        PRIORITÉ 2 : AUTO-COMPLÉTION VIA RÉFÉRENTIELS

        - communes : Sélection commune FR (nom, code INSEE, code postal, département)
          OK "Commune de résidence" (text) → communes
          KO "Adresse complète" (text) → utiliser "address" pas "communes"

        - departements : Sélection département FR
          OK "Département" (text) → departements

        - regions : Sélection région FR
          OK "Région" (text) → regions

        - pays : Pays ACTUELS uniquement
          OK "Pays de résidence actuel" (text) → pays
          KO "Pays de naissance" (text) → NE PAS utiliser (pays historiques manquants)
          KO "Nationalité" (text) → NE PAS utiliser (besoin pays historiques)

        - carte : Sélection de point, segment, polygones, parcelles cadastrale ou agricoles
          OK "Localisation du projet sur carte" (text) → carte

        PRIORITÉ 3 : UX SPÉCIALISÉE & VALIDATION SIMPLE

        - civilite : "Madame" ou "Monsieur" uniquement
          OK "Civilité" (text) → civilite

        - checkbox : Case à cocher pour consentements/attestations/engagements
          OK Libellé commence par "J'accepte", "J'atteste", "Je certifie", "Je m'engage", "Je déclare" → checkbox
          OK "J'accepte les CGU" (text) → checkbox
          OK "J'atteste sur l'honneur l'exactitude des informations" (text) → checkbox
          Si obligatoire : bloque la soumission si non coché

        - yes_no : Question factuelle binaire Oui/Non
          OK "Avez-vous un handicap reconnu ?" (text) → yes_no
          OK "Êtes-vous bénéficiaire du RSA ?" (text) → yes_no
          KO "J'accepte/J'atteste..." → utiliser checkbox, PAS yes_no

        - drop_down_list : Choix unique parmi liste
          OK Champ avec options textuelles → drop_down_list

        - multiple_drop_down_list : Choix multiples
          OK "Sélectionnez les options" → multiple_drop_down_list

        - date : Date seule avec calendrier
          OK "Date de naissance" (text) → date
          Options: date_in_past, start_date, end_date

        - datetime : Date + heure
          OK "Date et heure de début" (text) → datetime

        - integer_number : Nombre entier avec validation (min/max)
          OK "Nombre de bénéficiaires" (text) → integer_number
          KO "Code postal" (text) → NE PAS utiliser (utiliser "formatted")
          KO "Numéro de dossier" (text) → NE PAS utiliser (garder "text")
          Options: positive_number, min_number, max_number

        - decimal_number : Nombre décimal avec validation
          OK "Montant en euros" (text) → decimal_number
          Options: positive_number, min_number, max_number

        - formatted : UNIQUEMENT pour codes/identifiants à FORMAT STANDARDISÉ CONNU
          OK "Code postal français" → formatted { numbers_accepted: true, min_character_length: 5, max_character_length: 5 }
          OK "Immatriculation véhicule" → formatted (format AA-123-BB)
          KO "Nom" → NE JAMAIS utiliser formatted pour texte libre
          KO "Description" → NE JAMAIS utiliser formatted
          KO "Titre" → NE JAMAIS utiliser formatted

          IMPORTANT : Au moins une option *_accepted doit être true
          Options: letters_accepted, numbers_accepted, special_characters_accepted, min_character_length, max_character_length

        ## Options par type de champ:

        Pour "formatted" (codes/identifiants à format connu) :
        - letters_accepted (boolean): accepter les lettres
        - numbers_accepted (boolean): accepter les chiffres
        - special_characters_accepted (boolean): accepter les caractères spéciaux
        - min_character_length (integer): longueur minimale
        - max_character_length (integer): longueur maximale

        Pour "integer_number" / "decimal_number" :
        - positive_number (boolean): n'accepter que les valeurs positives
        - min_number (number): valeur minimale optionnelle
        - max_number (number): valeur maximale optionnelle

        Pour "date" / "datetime" :
        - date_in_past (boolean): n'accepter que les dates passées
        - start_date (string ISO): date minimale (ex: "2020-01-01")
        - end_date (string ISO): date maximale

        Note: Les options fournies seront fusionnées avec les options existantes du champ.
        Ne fournis que les options que tu souhaites modifier. Les options actuelles sont visibles dans le schéma du formulaire.

        ## GARDE-FOUS CRITIQUES (ne JAMAIS violer)

        - NE PAS transformer si le type actuel est déjà approprié
        - NE PAS utiliser "formatted" pour limiter la longueur de texte libre
        - NE PAS utiliser "integer_number" pour des codes/numéros métier sans validation numérique
        - NE PAS utiliser "pays" pour pays de naissance ou nationalité (manque pays historiques)
        - NE PAS transformer "address" en "communes" si l'adresse complète est nécessaire
        - NE PAS sur-spécialiser : un champ text libre doit rester text
        - NE PAS renseigner une "nature" sur une pièce justificative générique (limite à 1 fichier et aux formats document texte / scan)
        - NE PAS proposer "titre_identite" comme nature : ce choix relève de l'administration, pas d'une optimisation
        - NE PAS renseigner "nature" sur un type autre que "piece_justificative"

        >> Il vaut mieux ne faire AUCUNE proposition que de proposer une transformation inappropriée.

        ## Justification:
        - Quand un champ doit être modifié, fournis une courte justification qui sera affichée à l'administrateur pour lui expliquer les raisons pratiques du changement.
        - le texte ne doit pas comporter les libellés trop longs de champs
        - le texte ne doit pas comporter de détails techniques (HTML, code du type de champ, ids etc…).

        ## Concentre-toi sur les gains concrets :
        - Validation automatique (email, iban, siret)
        - Enrichissement de données (siret → données entreprise, address → commune/département/région)
        - Lecture automatique des documents déposés (justificatif de domicile, RIB, avis d'imposition → données transmises à l'instructeur)
        - Simplification pour l'usager (UX adaptée pour chaque champ, meilleure accessibilité)

        Utilise l'outil #{TOOL_DEFINITION.dig(:function, :name)} pour chaque proposition (un appel par changement).
        Ne réponds rien si tous les types sont déjà corrects.
      TXT
    end

    def build_item(args, tdc_index: {})
      build_update_item(args, tdc_index) if args['update']
    end

    private

    def build_update_item(args, tdc_index)
      data = args['update']
      return unless data.is_a?(Hash)

      stable_id = data['stable_id']
      type_champ = data['type_champ']
      nature = data['nature']

      return if stable_id.nil? || type_champ.blank?
      return unless valid_type_champ?(type_champ)
      return if nature.present? && !valid_nature?(type_champ, nature)

      original_tdc = tdc_index[stable_id]
      return if original_tdc && unchanged?(original_tdc, type_champ, nature)

      options = sanitize_options(type_champ, data['options'])

      payload = { 'stable_id' => stable_id, 'type_champ' => type_champ }
      payload['nature'] = nature if nature.present?
      payload['options'] = options if options.present?

      {
        op_kind: 'update',
        stable_id:,
        payload:,
        verify_status: 'pending',
        justification: args['justification'].presence,
      }
    end

    def valid_type_champ?(type_champ)
      TypeDeChamp.type_champs.key?(type_champ.to_s)
    end

    def valid_nature?(type_champ, nature)
      type_champ.to_s == TypeDeChamp.type_champs.fetch(:piece_justificative) &&
        TypeDeChamp.natures.key?(nature.to_s)
    end

    def unchanged?(original_tdc, type_champ, nature)
      return false if original_tdc.type_champ != type_champ
      return true if nature.blank?

      current_nature = original_tdc.nature || TypeDeChamp.natures.fetch(:non_specifie)
      current_nature == nature
    end

    def sanitize_options(type_champ, options)
      return nil if options.blank? || !options.is_a?(Hash)

      allowed_keys = TypeDeChamp.find_sti_class(type_champ).option_keys
      return nil if allowed_keys.blank?

      options.slice(*allowed_keys.map(&:to_s)).presence
    end
  end
end
