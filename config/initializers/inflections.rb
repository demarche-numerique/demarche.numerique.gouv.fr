# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
ActiveSupport::Inflector.inflections(:en) do |inflect|
  #  inflect.plural /^(ox)$/i, '\1en'
  #  inflect.singular /^(ox)en/i, '\1'
  #  inflect.irregular 'person', 'people'
  #  inflect.uncountable %w( fish sheep )
  inflect.acronym 'API'
  inflect.acronym 'ASN1'
  inflect.acronym 'IP'
  inflect.acronym 'JSON'
  inflect.acronym 'LLM'
  inflect.acronym 'OpenAI'
  inflect.acronym 'RIB'
  inflect.acronym 'RNA'
  inflect.acronym 'RNF'
  inflect.acronym 'URL'
  inflect.acronym 'SVA'
  inflect.acronym 'SVR'
  inflect.acronym 'FAQ'
  inflect.acronym 'FAQs'
  inflect.acronym 'OCR'
  inflect.irregular 'type_de_champ', 'types_de_champ'
  inflect.irregular 'type_de_champ_private', 'types_de_champ_private'
  inflect.irregular 'procedure_revision_type_de_champ', 'procedure_revision_types_de_champ'
  inflect.irregular 'revision_type_de_champ', 'revision_types_de_champ'
  inflect.irregular 'revision_type_de_champ_public', 'revision_types_de_champ_public'
  inflect.irregular 'revision_type_de_champ_private', 'revision_types_de_champ_private'
  inflect.irregular 'assign_to', 'assign_tos'
  inflect.uncountable(['avis', 'pays'])
end

# From https://github.com/davidcelis/inflections
ActiveSupport::Inflector.inflections(:fr) do |inflect|
  inflect.clear

  inflect.plural(/$/, 's')
  inflect.singular(/s$/, '')

  inflect.plural(/(bijou|caillou|chou|genou|hibou|joujou|pou|au|eu|eau)$/, '\1x')
  inflect.singular(/(bijou|caillou|chou|genou|hibou|joujou|pou|au|eu|eau)x$/, '\1')

  inflect.plural(/(bleu|émeu|landau|lieu|pneu|sarrau)$/, '\1s')
  inflect.plural(/al$/, 'aux')
  inflect.plural(/ail$/, 'ails')
  inflect.singular(/(journ|chev)aux$/, '\1al')
  inflect.singular(/ails$/, 'ail')

  inflect.plural(/(b|cor|ém|gemm|soupir|trav|vant|vitr)ail$/, '\1aux')
  inflect.singular(/(b|cor|ém|gemm|soupir|trav|vant|vitr)aux$/, '\1ail')

  inflect.plural(/(s|x|z)$/, '\1')

  inflect.irregular('monsieur', 'messieurs')
  inflect.irregular('madame', 'mesdames')
  inflect.irregular('mademoiselle', 'mesdemoiselles')
end
