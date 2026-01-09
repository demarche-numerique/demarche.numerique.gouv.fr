# frozen_string_literal: true

if defined?(RuboCop)
  module RuboCop
    module Cop
      module DS
        class FrenchApostrophe < Base
          extend AutoCorrector

          MSG = "Use modifier letter apostrophe ʼ (U+02BC) instead of ' (U+0027) or ' (U+2019) in French text"

          FRENCH_PATTERNS = [
            /\bl[''](?=[aeéèêiouAEÉÈÊIOU])/, # l'adresse, l'usager
            /\bd[''](?=[aeéèêiouAEÉÈÊIOU])/, # d'accord, d'un
            /\bn[''](?=[aeéèêiouAEÉÈÊIOU])/, # n'est, n'a
            /\bj[''](?=[aeéèêiouAEÉÈÊIOU])/, # j'ai
            /\bm[''](?=[aeéèêiouAEÉÈÊIOU])/, # m'inscrire
            /\bs[''](?=[aeéèêiouAEÉÈÊIOU])/, # s'inscrire, s'il
            /\bc[''](?=est\b)/, # c'est
            /\bqu[''](?=[io])/, # qu'il, qu'on
            /\baujourd['']hui\b/, # aujourd'hui
            /\bquelqu['']un\b/, # quelqu'un
          ].freeze

          def on_str(node)
            content = node.value
            return if content.match?(/\A\s*\z/) # skip empty/whitespace strings

            FRENCH_PATTERNS.each do |pattern|
              next unless content.match?(pattern)

              add_offense(node) do |corrector|
                # Replace ' or ' with ʼ (U+02BC)
                corrected_source = node.source.gsub(/['']/, 'ʼ')
                corrector.replace(node, corrected_source)
              end
              break # only report once per string
            end
          end
        end
      end
    end
  end
end
