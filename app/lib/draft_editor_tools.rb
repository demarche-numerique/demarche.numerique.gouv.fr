# frozen_string_literal: true

# The tools an assistant (Claude, Le Chat… any MCP client) is given to build
# the form of a démarche with its administrateur: DraftEditorService, one tool
# per operation. Served by API::V2::McpController, under the API token of the
# administrateur: the tools see the démarches the token sees, and write when
# it may write.
#
# Names and descriptions are in French: they are what the assistant reads to
# choose a tool, in a conversation held in French.
module DraftEditorTools
  INSTRUCTIONS = <<~TXT
    Ces outils modifient le brouillon du formulaire d’une démarche : rien n’est visible des usagers
    tant que l’administrateur n’a pas publié ses modifications depuis son interface.
    Commencer par `lire_demarche` : les autres outils désignent les champs par leur `stable_id`.
    Un champ se place après un autre champ du même bloc (formulaire usager, annotations privées,
    ou une même répétition). Une condition d’affichage ne peut citer que des champs placés avant
    le champ conditionné. En cas de refus, le message dit pourquoi et quoi corriger.
  TXT

  def self.server(context)
    MCP::Server.new(
      name: 'demarche_brouillon',
      title: "#{APPLICATION_NAME} – éditeur de formulaire",
      version: '0.1.0',
      instructions: INSTRUCTIONS,
      tools: Tool.descendants.sort_by(&:name_value),
      capabilities: { tools: { listChanged: false } },
      server_context: context
    )
  end

  class Tool < MCP::Tool
    DEMARCHE = { demarche: { type: 'integer', description: 'Le numéro de la démarche.' } }.freeze
    STABLE_ID = { type: 'string', description: 'Le `stable_id` du champ, tel que le donne `lire_demarche`.' }.freeze
    TYPE = { type: 'string', enum: TypeDeChamp.type_champs.values, description: 'Le type du champ. `lister_types_de_champ` décrit ceux de la démarche, avec leurs options.' }.freeze
    OPTIONS = { type: 'object', description: 'Les options propres au type du champ (voir `lister_types_de_champ`), par exemple `{ "drop_down_options": ["Oui", "Non"] }` pour une liste.' }.freeze

    class << self
      # The editor of the démarche, when the token gives access to it. Writing
      # takes a token that may write, as the mutations of the API do.
      def edit(server_context, demarche, write: true)
        procedure = Procedure.find_by(id: demarche)

        if procedure.nil? || server_context[:procedure_ids].exclude?(procedure.id)
          failure("La démarche « #{demarche} » n’existe pas ou le jeton utilisé n’y donne pas accès.")
        elsif write && !server_context[:write_access]
          failure("Le jeton utilisé est configuré seulement en lecture.")
        else
          result = yield DraftEditorService.new(procedure)
          result.is_a?(DraftEditorService::Result) ? respond(result) : json(result)
        end
      end

      def respond(result)
        result.success? ? json({ stable_id: result.stable_id }) : failure(*result.errors)
      end

      def json(payload) = MCP::Tool::Response.new([{ type: 'text', text: payload.to_json }])

      def failure(*messages) = MCP::Tool::Response.new([{ type: 'text', text: messages.join("\n") }], error: true)
    end
  end

  class LireDemarche < Tool
    tool_name 'lire_demarche'
    description "Lit le brouillon du formulaire d’une démarche : `champs` (le formulaire usager) et `annotations` (les annotations privées), chacun dans l’ordre du formulaire. Chaque champ a son `stable_id`, son type, ses options et sa condition d’affichage, au format attendu par `definir_condition` ; une répétition porte ses propres `champs`. Les titres de section sont des champs comme les autres, parmi leurs voisins."
    input_schema(properties: DEMARCHE, required: ['demarche'])
    annotations(read_only_hint: true)

    def self.call(demarche:, server_context:)
      edit(server_context, demarche, write: false, &:describe)
    end
  end

  class ListerTypesDeChamp < Tool
    tool_name 'lister_types_de_champ'
    description "Liste les types de champ utilisables sur une démarche, avec leur libellé, les options que chacun accepte, et où il peut être utilisé."
    input_schema(properties: DEMARCHE, required: ['demarche'])
    annotations(read_only_hint: true)

    def self.call(demarche:, server_context:)
      edit(server_context, demarche, write: false, &:type_champs)
    end
  end

  class AjouterChamp < Tool
    tool_name 'ajouter_champ'
    description "Ajoute un champ au brouillon. Sans `apres`, le champ est ajouté en premier dans son bloc. Renvoie le `stable_id` du champ créé."
    input_schema(
      properties: DEMARCHE.merge(
        type: TYPE,
        libelle: { type: 'string', description: 'Le libellé du champ, tel que le lit l’usager.' },
        description: { type: 'string', description: 'Le texte d’aide affiché sous le libellé.' },
        obligatoire: { type: 'boolean', description: 'Le champ doit-il être rempli ? Non par défaut.' },
        annotation_privee: { type: 'boolean', description: 'Ajouter le champ aux annotations privées, réservées aux instructeurs, plutôt qu’au formulaire usager.' },
        parent: STABLE_ID.merge(description: 'Le `stable_id` de la répétition dans laquelle ajouter le champ.'),
        apres: STABLE_ID.merge(description: 'Le `stable_id` du champ après lequel ajouter le champ.'),
        options: OPTIONS
      ),
      required: ['demarche', 'type', 'libelle']
    )

    def self.call(demarche:, type:, libelle:, server_context:, description: nil, obligatoire: false, annotation_privee: false, parent: nil, apres: nil, options: nil)
      edit(server_context, demarche) do |editor|
        editor.add(type_champ: type, libelle:, description:, mandatory: obligatoire, private: annotation_privee, parent_stable_id: parent, after_stable_id: apres, options:)
      end
    end
  end

  class ModifierChamp < Tool
    tool_name 'modifier_champ'
    description "Modifie un champ du brouillon : son libellé, sa description, son caractère obligatoire, son type, ses options. Seul ce qui est fourni change. Le type d’un champ déjà publié ne peut devenir qu’un type compatible avec les dossiers déjà déposés."
    input_schema(
      properties: DEMARCHE.merge(
        stable_id: STABLE_ID,
        libelle: { type: 'string' },
        description: { type: 'string' },
        obligatoire: { type: 'boolean' },
        type: TYPE,
        options: OPTIONS
      ),
      required: ['demarche', 'stable_id']
    )

    def self.call(demarche:, stable_id:, server_context:, libelle: nil, description: nil, obligatoire: nil, type: nil, options: nil)
      edit(server_context, demarche) do |editor|
        editor.update(stable_id, libelle:, description:, mandatory: obligatoire, type_champ: type, options:)
      end
    end
  end

  class DeplacerChamp < Tool
    tool_name 'deplacer_champ'
    description "Déplace un champ dans son bloc : après le champ `apres`, ou en premier sans lui."
    input_schema(
      properties: DEMARCHE.merge(stable_id: STABLE_ID, apres: STABLE_ID.merge(description: 'Le `stable_id` du champ après lequel placer le champ.')),
      required: ['demarche', 'stable_id']
    )

    def self.call(demarche:, stable_id:, server_context:, apres: nil)
      edit(server_context, demarche) { it.move(stable_id, after_stable_id: apres) }
    end
  end

  class SupprimerChamp < Tool
    tool_name 'supprimer_champ'
    description "Supprime un champ du brouillon. Une répétition est supprimée avec ses champs. Refusé tant qu’une condition d’affichage, le routage ou un référentiel utilise le champ."
    input_schema(properties: DEMARCHE.merge(stable_id: STABLE_ID), required: ['demarche', 'stable_id'])
    annotations(destructive_hint: true)

    def self.call(demarche:, stable_id:, server_context:)
      edit(server_context, demarche) { it.remove(stable_id) }
    end
  end

  class DefinirCondition < Tool
    tool_name 'definir_condition'
    description "Définit la condition d’affichage d’un champ : il n’est montré que si les termes sont vérifiés (tous avec `and`, l’un d’eux avec `or`). Remplace la condition existante ; une liste de termes vide la retire."
    input_schema(
      properties: DEMARCHE.merge(
        stable_id: STABLE_ID,
        operator: { type: 'string', enum: DraftEditorService::TOP_OPERATORS.keys, description: 'Comment combiner les termes. `and` par défaut.' },
        terms: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              source_stable_id: STABLE_ID.merge(description: 'Le `stable_id` du champ comparé, placé avant le champ conditionné.'),
              operator: { type: 'string', enum: DraftEditorService::OPERATORS.keys },
              value: { type: 'string', description: 'La valeur comparée : un nombre, `true` ou `false` pour un oui/non ou une case à cocher, une option d’une liste, un code de département ou de région.' },
              source_column: { type: 'string', description: 'À renvoyer tel quel quand `lire_demarche` le donne.' },
            },
            required: ['source_stable_id', 'operator', 'value'],
          },
        }
      ),
      required: ['demarche', 'stable_id', 'terms']
    )

    def self.call(demarche:, stable_id:, terms:, server_context:, operator: 'and')
      edit(server_context, demarche) { it.set_condition(stable_id, operator:, terms:) }
    end
  end
end
