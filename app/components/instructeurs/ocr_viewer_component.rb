# frozen_string_literal: true

class Instructeurs::OCRViewerComponent < ApplicationComponent
  attr_reader :champ, :doc, :two_ddoc

  def initialize(champ:)
    @champ = champ
    @doc = champ.ocr_result
    @two_ddoc = @doc.try(:two_ddoc)
  end

  def render? = doc.present?

  def data
    d = if doc.is_a?(RIB)
      h = doc.attributes.slice('account_holder', 'iban', 'bic', 'bank_name')
      h['account_holder'] = format_multiline(h['account_holder'])
      rows = h.map { |k, v| [k, v || processing_error_message, copy: v.present?] }
      rows.insert(1, ['account_holder_match', account_holder_match_badge, copy: false]) if account_holder_match?
      rows

    elsif doc.is_a?(JustificatifDomicile)
      h = doc.attributes.slice('beneficiary', 'label', 'issue_date')
      h['issue_date'] = I18n.l(h['issue_date'], format: :short) if h['issue_date']
      h

    elsif doc.is_a?(AvisImpot)
      h = doc.attributes.slice('declarant_1', 'declarant_2', 'reference_avis', 'annee_des_revenus', 'nombre_de_parts', 'revenu_fiscal_de_reference', 'date_mise_en_recouvrement', 'label')
      h['date_mise_en_recouvrement'] = I18n.l(h['date_mise_en_recouvrement'], format: :short) if h['date_mise_en_recouvrement']
      h
    end

    d.map { |k, *tail| [doc.class.human_attribute_name(k), *tail] }
  end

  def source
    tag.acronym(title: t('.two_ddoc_title')) { '2D-Doc' } if two_ddoc
  end

  def untrusted = !two_ddoc

  private

  def format_multiline(text) = sanitize(text&.split("\n")&.join('<br>'))

  def account_holder_match? = champ.type_de_champ.rib_account_holder_match? && champ.value_json&.key?('account_holder_match')

  def account_holder_match_badge
    case champ.value_json['account_holder_match']
    in true then tag.span(t('.account_holder_match.yes'), class: 'fr-badge fr-badge--sm fr-badge--success')
    in false then tag.span(t('.account_holder_match.no'), class: 'fr-badge fr-badge--sm fr-badge--warning')
    in nil then tag.span(t('.account_holder_match.unknown'), class: 'fr-badge fr-badge--sm')
    end
  end

  def processing_error_message
    content_tag(:span, class: "fr-hint-text fr-text-default--warning font-weight-normal") do
      concat dsfr_icon('fr-icon-alert-line', :sm, :mr)
      concat t('.processing_error')
    end
  end
end
