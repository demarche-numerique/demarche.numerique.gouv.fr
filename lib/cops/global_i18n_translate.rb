# frozen_string_literal: true

if defined?(RuboCop)
  module RuboCop
    module Cop
      module DS
        # In code with a locally-bound translation helper (views, components,
        # controllers, helpers, mailers), `t` must be preferred over `I18n.t`:
        # it resolves relative keys, marks missing translations, and makes
        # `_html` keys html_safe while still escaping interpolated arguments.
        # `I18n.t` belongs in models, jobs and services — or anywhere a
        # `locale:` override is passed explicitly.
        class GlobalI18nTranslate < Base
          MSG = 'Use the locally-bound `t` instead of `I18n.t` (relative keys, ' \
                'missing-translation markers, safe `_html` handling). ' \
                'Reserve `I18n.t` for models/jobs/services or explicit `locale:` overrides.'

          def_node_matcher :global_translate?, <<~PATTERN
            (send (const {nil? cbase} :I18n) {:t :t! :translate :translate!} ...)
          PATTERN

          def_node_matcher :locale_override?, <<~PATTERN
            (send _ _ ... (hash <(pair (sym :locale) _) ...>))
          PATTERN

          def on_send(node)
            return unless global_translate?(node)
            return if locale_override?(node)
            # Class methods have no instance translation helper (ViewComponent's
            # class-level `t` only reads the sidecar backend, never global keys).
            return if class_method_context?(node)

            add_offense(node)
          end

          private

          def class_method_context?(node)
            node.each_ancestor(:def, :defs, :sclass).first&.type&.then { it != :def } || false
          end
        end
      end
    end
  end
end
