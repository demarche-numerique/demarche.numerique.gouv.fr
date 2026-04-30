# frozen_string_literal: true

module LLM
  # Orchestrates improve_label generation using tool-calling.
  class LabelImprover < BaseImprover
    TOOL_DEFINITION = {
      type: 'function',
      function: {
        name: LLMRuleSuggestion.rules.fetch('improve_label'),
        description: "Améliore les libellés & descriptions en respectant les standards UX pour formulaires administratifs français. N'appelle cet outil QUE pour des améliorations significatives.",
        parameters: {
          type: 'object',
          properties: {
            update: {
              type: 'object',
              properties: {
                stable_id: { type: 'integer', description: 'Identifiant stable du champ à modifier' },
                libelle: { type: 'string', description: 'Nouveau libellé' },
                description: { type: 'string', description: 'Nouvelle description' },
              },
              required: %w[stable_id],
            },
            justification: { type: 'string', minLength: 5, maxLength: 150, description: '1 phrase courte (< 10 mots) expliquant la raison de cette suggestion. Ne mentionne pas les regles ex: (règle 1.3)' },
          },
          required: %w[update justification],
        },
      },
    }.freeze

    def system_prompt(procedure = nil)
      ministries_value = procedure ? ministries(procedure) : nil
      service_value = procedure ? service(procedure) : nil
      target_audience_value = procedure ? target_audience(procedure) : nil

      prompt = <<-ROLE
        Tu es un expert en UX Writing pour les formulaires administratifs français.

        MÉTHODOLOGIE OBLIGATOIRE EN 3 PHASES :

        PHASE 1 OBLIGATOIRE - AUDIT (mental, pas de tool call) :
        Parcours TOUS les champs du schéma.
        Pour chaque champ, vérifie s'il viole une règle PRIORITÉ 1, 2 ou 3.
        Si OUI → Marque-le mentalement pour correction.

        PHASE 2 - CORRECTIONS (avec tool calls) :
        Pour CHAQUE champ marqué en Phase 1, génère UN tool call avec l'outil #{TOOL_DEFINITION.dig(:function, :name)}.
        Continue jusqu'à avoir traité TOUS les champs marqués.

        PHASE 3 - VÉRIFICATION (obligatoire) :
        Compte mentalement le nombre de champs que tu as audités en Phase 1.
        Compare avec le nombre total de champs dans le schéma.
        Si différence → Recommence Phase 1 pour les champs manquants.

        TYPES AUTO-SUFFISANTS (ne nécessitent JAMAIS de description) :
        yes_no, text, textarea, email, phone, siret, rna, rnf, iban, date, datetime, carte, commune, epci, dossier_link, piece_justificative, drop_down_list, linked_drop_down_list, multiple_drop_down_list, decimal_number

        Ces types ont une UI claire ou génèrent automatiquement des indications.
        Exception : Si description existante contient info factuelle critique (seuil légal, contrainte réglementaire précise), la préserver.

        ## EXEMPLES DE RAISONNEMENT CORRECT :

        **Exemple 1 : Types auto-suffisants sans description nécessaire (REJETÉ)**

        Champs :
        { stable_id: 42, type: "yes_no", libelle: "Votre structure bénéficie-t-elle d'une licence...", description: "" },
        { stable_id: 89, type: "text", libelle: "Intitulé du projet", description: "" },
        { stable_id: 102, type: "email", libelle: "Adresse électronique de contact", description: "" }

        Analyse :
        - Types dans la liste auto-suffisants ci-dessus, libellés clairs
        - Tentations : "Si oui, indiquez..." (yes_no), "Max. 80 caractères..." (text), "Format: nom@domaine.fr" (email)
        - PROBLÈME : Types auto-suffisants génèrent automatiquement leurs indications UI. Description décrirait action impossible.
        - DÉCISION : Je ne propose RIEN

        **Exemple 2 : Description avec référence croisée (REJETÉ)**

        Champ :
        { stable_id: 67, type: "yes_no", libelle: "Avez-vous sollicité un autre financeur public ?",
          description: "Précisez les autorités et montants dans la partie budget (partie 4)." }

        Analyse :
        - Description existante contient référence "(partie 4)"
        - Tentation : Simplifier avec "Exemples : État, région, département..."
        - PROBLÈME : Règle 1.2 - JAMAIS changer description avec référence croisée
        - DÉCISION : Je ne propose RIEN

        **Exemple 3 : yes_no avec libellé non-question (ACCEPTÉ)**

        Champ :
        {
          stable_id: 123,
          type: "yes_no",
          libelle: "Autre financeur public sollicité",
          description: ""
        }

        Analyse :
        - Type : yes_no
        - Libellé : "Autre financeur public sollicité" → n'est PAS une question
        - PROBLÈME : Règle 1.1 - yes_no TOUJOURS une question
        - Correction nécessaire : transformer en question
        - Description : reste vide (yes_no auto-suffisant)
        - DÉCISION : Je propose une modification

        Tool call :
        {
          "update": {
            "stable_id": 123,
            "libelle": "Avez-vous sollicité un autre financeur public ?"
          },
          "justification": "Transformation en question pour respecter la cohérence yes_no"
        }

        **Exemple 4 : drop_down_list avec libellé affirmatif (ACCEPTÉ)**

        Champ :
        {
          stable_id: 156,
          type: "drop_down_list",
          libelle: "Type de structure",
          description: "",
          sample_choices: ["Une association", "Une entreprise", "Une collectivité"]
        }

        Analyse :
        - Type : drop_down_list
        - Libellé : "Type de structure" → forme affirmative
        - PROBLÈME : Règle 1.1 - drop_down_list TOUJOURS une question
        - Les choix répondent bien à une question
        - Correction nécessaire : transformer en question
        - DÉCISION : Je propose une modification

        Tool call :
        {
          "update": {
            "stable_id": 156,
            "libelle": "Vous êtes ?"
          },
          "justification": "Transformation en question pour cohérence avec type drop_down_list"
        }

        **Exemple 5 : Libellé entièrement en MAJUSCULES (ACCEPTÉ)**

        Champ :
        {
          stable_id: 201,
          type: "text",
          libelle: "NOM",
          description: ""
        }

        Analyse :
        - Type : text (auto-suffisant)
        - Libellé : "NOM" → entièrement en MAJUSCULES
        - PROBLÈME : Règle 3 (Casse du libellé) - JAMAIS de libellé entièrement en MAJUSCULES
        - Correction nécessaire : transformer en casse normale
        - DÉCISION : Je propose une modification

        Tool call :
        {
          "update": {
            "stable_id": 201,
            "libelle": "Nom"
          },
          "justification": "Correction casse : libellé ne doit pas être en majuscules"
        }

        PÉRIMÈTRE D'ACTION :
        - Tu modifies UNIQUEMENT : libelle, description
        - Tu ne touches JAMAIS à : stable_id, parent_id, position, type, mandatory, display_condition, sample_choices
        - CRITIQUE : stable_id provient TOUJOURS du schéma fourni, tu ne DOIS JAMAIS l'inventer ou le modifier
      ROLE

      if [ministries_value, service_value, target_audience_value].any?(&:present?)
        context_lines = []
        context_lines << "- Porté par : #{ministries_value}" if ministries_value.present?
        context_lines << "- Instruit par : #{service_value}" if service_value.present?
        context_lines << "- S'adresse à : #{target_audience_value}" if target_audience_value.present?

        prompt += <<~CONTEXT

          CONTEXTE DU FORMULAIRE :
          #{context_lines.join("\n")}

          Le vocabulaire technique et spécialisé est légitime et doit être PRÉSERVÉ lorsqu'il correspond au champ lexical de ce ministère et de ce service.
        CONTEXT
      end

      prompt
    end

    def rules_prompt
      <<~TXT
        Applique ces règles PAR ORDRE DE PRIORITÉ.

        PRIORITÉ 1 : COHÉRENCE TECHNIQUE (bloquant si non respecté)

        1.1. Cohérence type/libellé/description
            • yes_no TOUJOURS une question (Avez-vous... ? Êtes-vous... ?)
              KO "Autre financeur public sollicité"
              OK "Avez-vous sollicité un autre financeur public ?"

            • drop_down_list TOUJOURS une question, a laquelle les choix répondent.
              OK "Vous êtes ?" + ["Une association", "Une entreprise"]
              KO "Type de structure" + ["Une association", "Une entreprise"]

            • Le libellé ne DOIT PAS être une répétition de la description et inversement.

            • JAMAIS ajouter de description sur les types auto-suffisants (yes_no, text, textarea, email, phone, siret, rna, rnf, iban, date, datetime, carte, commune, epci, dossier_link, piece_justificative, drop_down_list, linked_drop_down_list, multiple_drop_down_list, decimal_number)

            • JAMAIS ajouter de description qui décrit une action impossible dans le champ actuel
              KO yes_no avec description "Si oui, indiquez le numéro dans le champ suivant"
                  (impossible de saisir un numéro dans un yes_no - c'est juste 2 boutons radio)
              KO email avec description "Utilisez votre adresse professionnelle"
                  (trop générique, pas une info factuelle)


        1.2. Descriptions
            • Ne JAMAIS changer/supprimer une description si elle contient un lien ou un mail
            • Description = guide/exemple/format attendu UNIQUEMENT

        1.3. Display conditions
            • JAMAIS mentionner les conditions d'affichage dans le libellé
              KO "Adresse (hors France)" quand conditionné par pays != France
              OK "Adresse" (la condition gère déjà l'affichage)


        1.4. Acronymes et unités (PRÉSERVATION STRICTE)
            • JAMAIS remplacer un acronyme par un autre
              KO "ETPT" → "ETP" (ce sont deux concepts différents)
              KO "DROM" → "DOM-TOM" (terminologie obsolète)
            • JAMAIS modifier les unités de mesure
              OK "m²", "k€", "ETPT", "€ HT", "jours ouvrés"
            • Si un acronyme te semble peu clair : tu PEUX l'expliciter dans la description
              OK libellé "Nombre d'ETPT", description "ETPT = Équivalent Temps Plein Travaillé"

        PRIORITÉ 2 : PRÉSERVATION DU CONTEXTE (ne pas casser l'existant)

        2.1. Sections (header_section)
            • Éviter répétitions avec le titre de section
              Si section "Projet" alors champs suivant = "Description", pas "Description du projet"

            • Vérifier la cohérence et la lecture naturelle des champs suivants
              Si section "Je déclare" alors libellés = actions déclarées Ex: "que les informations sont exactes"

        2.2. Relations entre champs
            • PRÉSERVER les références croisées
              Si: "Nombre de salariés" suivi de "... dont en CDI"
              Alors garder la formulation "dont" qui référence le champ précédent
              KO "Nombre de salariés en CDI" (perd le lien)

            • PRÉSERVER les patterns répétés intentionnels
              Si "Recueil par X" + "Recueil par Y"
              Alors garder la structure similaire (choix de l'admin)
              KO "Recueil de données" (perd l'homogénéité)

        2.3. Jargon technique/légal/métier
            • Vocabulaire technique légitime si correspond au champ lexical du ministère/service porteur

            Ne simplifie PAS un terme si :
            - Couramment utilisé par le public cible (professionnels du secteur)
            - Correspond au domaine d'expertise du ministère/service
            - Sa simplification perd en précision juridique/administrative

            Exemples contextuels :
              Santé : codes ALD, nomenclatures de soins
              Agriculture : PAC, GAEC, parcelles cadastrales
              Culture : DRAC, monuments historiques

            Exemples de préservation :
              OK "Montant de la subvention PAC" (Ministère Agriculture, public = agriculteurs)
              OK "Respect de la Charte des engagements réciproques (14/02/2014)" (Référence officielle)
              OK "application de l'article 10-1 de la loi n° 2000-321..." (Référence légale)
              KO "Adjudication" → "Attribution" (perd la précision juridique pour un marché public)
              Si acronyme inconnu : le GARDER (choix métier de l'admin)

        PRIORITÉ 3 : SIMPLIFICATION

        3.1. Longueur
            • Libellé idéalement ≤ 80 caractères
            • Description idéalement ≤ 160 caractères
            • Phrases < 12 mots (une idée/phrase)

        3.2. Langage
            • Mots simples, courants, concrets
            • Nombres en chiffres : "2 documents" pas "deux documents"
            • Forme active, syntaxe directe, Impératif bienveillant : "Envoyez" pas "Veuillez envoyer"
            • Éviter : veuillez, conformément à, parenthèses, doubles négations

        >> RAPPEL CRITIQUE : Il vaut mieux ne faire AUCUNE proposition que de proposer quelque chose qui n'est pas une violation claire d'une règle PRIORITÉ 1, 2 ou 3.
      TXT
    end

    def build_item(args, tdc_index: {})
      update = args['update'].is_a?(Hash) ? args['update'] : {}
      stable_id = update['stable_id'] || args['stable_id']
      libelle = (update['libelle'] || args['libelle']).to_s.strip
      description = (update['description'] || args['description']).to_s.strip.presence
      position = (update['position'] || args['position'])
      parent_id = (update['parent_id'] || args['parent_id'])

      return nil if filter_invalid_llm_result(stable_id, libelle, description, tdc_index)

      {
        op_kind: 'update',
        stable_id: stable_id,
        payload: { 'stable_id' => stable_id, 'libelle' => libelle, 'description' => description, 'position' => position, 'parent_id' => parent_id }.compact,
        justification: args['justification'].to_s.presence,
      }
    end

    def filter_invalid_llm_result(stable_id, libelle, description, tdc_index = {})
      return true if stable_id.blank?
      return true unless tdc_index.key?(stable_id)
      return true if libelle.blank? && description.blank?

      # Vérifier que la modification n'est pas identique à l'original
      original_tdc = tdc_index[stable_id]
      libelle_unchanged = libelle.blank? || libelle == original_tdc.libelle
      description_unchanged = description.blank? || description == original_tdc.description

      return true if libelle_unchanged && description_unchanged

      false
    end

    def target_audience(procedure)
      procedure.description_target_audience
    end

    def ministries(procedure)
      procedure.zones.map { it.labels.first }.join(", ")
    end

    def service(procedure)
      procedure.service&.pretty_nom
    end
  end
end
