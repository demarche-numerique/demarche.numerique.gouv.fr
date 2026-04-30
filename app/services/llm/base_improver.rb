# frozen_string_literal: true

module LLM
  class BaseImprover
    # Maximum fields per batch for improve_label to avoid timeout
    IMPROVE_LABEL_MAX_FIELD_BEFORE_TIMEOUT = 50

    # Characters that could potentially interfere with LLM prompts or cause security issues
    DANGEROUS_CHARS = /
      [<>{}\[\]]     # Markup characters that could be used for injections
      | [\x00-\x1F]  # Control characters (null, tab, line feed, etc.)
      | \x7F         # Delete character
    /x.freeze

    # Mapping of field types to their descriptions
    FIELD_TYPES = {
      # Champs structurels
      'header_section' => "pour structurer le formulaire en sections (aucune saisie attendue, uniquement un libelle qui est le titre de la section). Les champs compris entre deux sections appartiennent à la section la plus proche au dessus.",
      'repetition' => "pour des blocs répétables de champs enfants ; l’usager peut répéter le bloc autant de fois qu’il le souhaite. Les champs enfants sont liés a la répétition par leur parent_id.",
      'explication' => "pour fournir du contexte ou des consignes (aucune saisie attendue).",

      # Champs personnels
      'civilite' => "pour choisir « Madame » ou « Monsieur » ; l’administration connaît déjà cette information.",
      'email' => "pour les adresses électroniques ; l’administration connaît déjà l’email de l’usager.",
      'phone' => "pour les numéros de téléphone.",
      'address' => "pour les adresses postales (auto-complétées avec commune, codes postaux, département, etc.).",
      'communes' => "pour sélectionner des communes fran  çaises (auto-complétées avec code, code postal, département, etc.).",
      'departements' => "pour sélectionner des départements français.",
      'regions' => "pour sélectionner des régions françaises.",
      'pays' => "pour sélectionner des pays.",
      'iban' => "pour les numéros IBAN.",
      'siret' => "pour les numéros SIRET.",

      # Champs saisie
      'text' => "pour des champs texte courts.",
      'textarea' => "pour des champs texte longs.",
      'number' => "pour des nombres (entiers ou décimaux).",
      'decimal_number' => "pour des nombres décimaux.",
      'integer_number' => "pour des nombres entiers.",
      'formatted' => "pour des champs texte formatés (avec masques).",
      'date' => "pour sélectionner une date.",
      'datetime' => "pour sélectionner une date et heure.",
      'piece_justificative' => "pour téléverser des pièces justificatives (inutile de l’enfermer dans une répétition : plusieurs fichiers sont déjà possibles).",

      'checkbox' => "pour une case à cocher unique.",
      'drop_down_list' => "pour un choix unique dans une liste déroulante (options configurées ailleurs par l’administration).",
      'multiple_drop_down_list' => "pour un choix multiple dans une liste déroulante (options configurées ailleurs par l’administration).",
      'linked_drop_down_list' => "pour des listes déroulantes liées.",
      'yes_no' => "pour une question à réponse oui / non.",
      'dossier_link' => "pour lier à un autre dossier.",

      # Champs référentiels
      'annuaire_education' => "pour rechercher dans l'annuaire éducation.",
      'rna' => "pour les numéros RNA.",
      'rnf' => "pour les numéros RNF.",
      'carte' => "pour afficher une carte interactive.",
      'cnaf' => "pour les données CNAF.",
      'dgfip' => "pour les données DGFIP.",
      'pole_emploi' => "pour les données Pôle Emploi.",
      'mesri' => "pour les données MESRI.",
      'epci' => "pour les EPCI.",
      'cojo' => "pour les données COJO.",
      'referentiel' => "pour des référentiels externes génériques.",
      'engagement_juridique' => "pour des engagements juridiques.",
    }.freeze

    # Grouping of field types
    FIELD_GROUPS = {
      "Champs structurels" => ["header_section", "repetition", "explication"],
      "Champs personnels" => ["civilite", "email", "phone", "address", "communes", "departements", "regions", "pays", "iban", "siret"],
      "Champs saisie" => ["text", "textarea", "number", "decimal_number", "integer_number", "formatted", "date", "datetime", "piece_justificative", "checkbox", "drop_down_list", "multiple_drop_down_list", "linked_drop_down_list", "yes_no", "dossier_link"],
      "Champs référentiels" => ["annuaire_education", "rna", "rnf", "carte", "cnaf", "dgfip", "pole_emploi", "mesri", "epci", "cojo", "referentiel", "engagement_juridique"],
    }.freeze

    def initialize(runner: nil, logger: Rails.logger)
      @runner = runner
      @logger = logger
    end

    def section_explanation
      <<~TXT
        IMPORTANT - COMPRENDRE LES SECTIONS :
        Le formulaire est structuré en sections pour organiser les champs.
        Une section est définie par un champ header_section suivi de tous les champs qui viennent après, jusqu'au prochain header_section de même niveau (ou la fin du formulaire).

        Pour identifier la section d'un champ : cherche le dernier header_section AVANT ce champ (en regardant les positions).
        Si aucun header_section avant → le champ n'a pas de section.
      TXT
    end

    # Returns an array of hashes suitable for LlmRuleSuggestionItem creation
    # [{ rule:, op_kind:, stable_id:, payload:, justification: }]
    def generate_for(suggestion, action: nil, user_id: nil)
      schema = sanitize_schema_for_prompt(suggestion.procedure_revision.schema_to_llm)
      batches = create_batches_for_suggestion(schema, suggestion)

      all_tool_calls = []
      total_usage = { prompt_tokens: 0, completion_tokens: 0 }

      batches.each do |batch_schema|
        messages = propose_messages_with_schema(suggestion.procedure_revision, batch_schema)

        tool_calls, token_usage = run_tools(
          messages: messages,
          tools: [self.class::TOOL_DEFINITION],
          procedure_id: suggestion.procedure_revision.procedure_id,
          rule: suggestion.rule,
          action:,
          user_id:
        )

        all_tool_calls.concat(tool_calls)
        token_usage = token_usage.with_indifferent_access
        total_usage[:prompt_tokens] += token_usage['prompt_tokens'].to_i
        total_usage[:completion_tokens] += token_usage['completion_tokens'].to_i
      end

      [aggregate_calls(all_tool_calls, suggestion), total_usage.with_indifferent_access]
    end

    private

    def run_tools(messages:, tools:, procedure_id: nil, rule: nil, action: nil, user_id: nil)
      return [] unless @runner

      @runner.call(messages: messages, tools: tools, procedure_id:, rule:, action:, user_id:) || []
    end

    def propose_messages(suggestion)
      propose_messages_for_procedure(suggestion.procedure_revision)
    end

    def propose_messages_for_procedure(procedure_revision)
      safe_schema = sanitize_schema_for_prompt(procedure_revision.schema_to_llm(reject: reject_schema_to_llm_scope))
      propose_messages_with_schema(procedure_revision, safe_schema)
    end

    def propose_messages_with_schema(procedure_revision, schema)
      unique_types = procedure_revision.types_de_champ.map(&:type_champ).uniq
      field_types_description = format_field_types(unique_types)

      [
        { role: 'system', content: system_prompt(procedure_revision.procedure) },
        {
          role: 'user',
          content: format(
            procedure_prompt,
            schema: schema,
            procedure_description: procedure_revision.procedure.description,
            procedure_libelle: procedure_revision.procedure.libelle,
            field_types: field_types_description
          ),
        },
        { role: 'user', content: rules_prompt },
      ]
    end

    def aggregate_calls(tool_calls, suggestion)
      tdc_index = suggestion.procedure_revision.types_de_champ.index_by(&:stable_id)

      tool_calls
        .filter { |call| call[:name] == suggestion.rule }
        .map do |call|
          args = call[:arguments] || {}
          build_item(args, tdc_index:)
        end
        .compact
    end

    def create_batches_for_suggestion(schema, suggestion, level: 1)
      case suggestion.rule
      when LLMRuleSuggestion.rules.fetch('improve_label'),
           LLMRuleSuggestion.rules.fetch('cleaner')
        batch_by_sections(schema, suggestion, level)
      when LLMRuleSuggestion.rules.fetch('improve_structure')
        batch_by_parent_id(schema)
      else
        [schema]
      end
    end

    def batch_by_parent_id(schema)
      root_fields, _repetition_fields = schema.partition { |field| field[:parent_id].nil? }

      [root_fields]
    end

    def batch_by_sections(schema, suggestion, level)
      sections = split_by_section_level(schema, level)
      merged = merge_small_sections(sections)
      merged.flat_map { |batch| split_if_needed(batch, suggestion, level) }
    end

    private

    def split_by_section_level(schema, level)
      schema.slice_before do |field|
        field[:type] == 'header_section' && field[:header_section_level] == level
      end.to_a
    end

    def merge_small_sections(sections)
      sections.each_with_object([[]]) do |section, batches|
        if batches.last.empty? || (batches.last.size + section.size) <= IMPROVE_LABEL_MAX_FIELD_BEFORE_TIMEOUT
          batches.last.concat(section)
        else
          batches << section
        end
      end
    end

    def split_if_needed(batch, suggestion, level)
      return [batch] if batch.size <= IMPROVE_LABEL_MAX_FIELD_BEFORE_TIMEOUT

      level < 3 ? create_batches_for_suggestion(batch, suggestion, level: level + 1)
                : batch.each_slice(IMPROVE_LABEL_MAX_FIELD_BEFORE_TIMEOUT).to_a
    end

    def procedure_prompt
      <<~PROMPT
        Le titre de ce formulaire est :
        <procedure_libelle>
          %<procedure_libelle>s
        </procedure_libelle>

        L'objet de ce formulaire est :
        <procedure_description>
          %<procedure_description>s
        </procedure_description>

        Voici le schéma des champs (publics) du formulaire en JSON. Chaque entrée contient :
          - stable_id : l'identifiant du champ
          - type : le type de champ (voir liste plus bas)
          - libellé : le libellé du champ
          - mandatory : indique si le champ est obligatoire ou non
          - description : la description du champ (optionnel)
          - total_choices : le nombre total d'options disponibles pour les champs de type liste déroulante (drop_down_list ou multiple_drop_down_list)
          - sample_choices : quelques exemples d'options disponibles pour les champs de type liste déroulante (drop_down_list ou multiple_drop_down_list)
          - choices_dynamic : boolean indiquant si les options du champ sont issues d'un référentiel externe (true) ou non (false ou absent)
          - position : la position du champ dans le formulaire, dans une une répétition la position est relative à la répétition et commence a 0
          - parent_id : stable_id du champ parent, ou null s’il n’y a pas de parent (donc ce champ est un enfant d’une répétition)
          - header_section_level : le niveau de section si le champ est de type header_section
          - display_condition : une condition d'affichage, optionnelle, dépendant de valeurs saisies préalablement par l'usager. Si cette condition est vraie le champ sera affiché, sinon il sera masqué, même s'il est obligatoire.

          Les types de champ utilisés dans ce formulaire sont :
          %<field_types>s

          <schema>
          %<schema>s
          </schema>
      PROMPT
    end

    def format_field_types(unique_types)
      FIELD_GROUPS.map do |group_name, types_in_group|
        present_types = types_in_group & unique_types
        next if present_types.empty?

        lines = ["- **#{group_name}** :"]
        present_types.each do |type|
          description = FIELD_TYPES[type]
          lines << "  - #{type} : #{description}" if description
        end
        lines.join("\n")
      end.compact.join("\n\n")
    end

    def sanitize_schema_for_prompt(schema)
      return schema unless schema.is_a?(Array)

      schema.map do |field|
        field.transform_values do |value|
          case value
          when Array
            Array(value).map { |choice| choice.is_a?(String) ? sanitize_input_to_llm(choice) : choice }
          when String
            sanitize_input_to_llm(value)
          else
            value
          end
        end
      end
    end

    def sanitize_input_to_llm(input)
      input.gsub(DANGEROUS_CHARS, '').strip
    end

    def reject_schema_to_llm_scope
      []
    end
  end
end
