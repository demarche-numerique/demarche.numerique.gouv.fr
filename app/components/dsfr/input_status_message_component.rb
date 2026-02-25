# frozen_string_literal: true

module Dsfr
  class InputStatusMessageComponent < ApplicationComponent
    include EtablissementHelper
    delegate :type_de_champ, to: :@champ
    delegate :prefilled?, to: :@champ

    def initialize(champ_component:, champ:, row_number: nil)
      @errors_on_attribute = champ_component.errors_on_attribute?
      @error_full_messages = champ_component.error_full_messages
      @error_id = champ.error_id(champ_component.attribute)
      @champ = champ
      @row_number = row_number
    end

    def statutable?
      siret_support_status? ||
      rna_support_statut? ||
      referentiel_support_statut? ||
      dossier_link_support_statut? ||
      prefilled? ||
      pjs_statut?
    end

    def siret_support_status?
      type_de_champ.siret? && @champ.external_id.present?
    end

    def rna_support_statut?
      type_de_champ.rna? && @champ.value.present?
    end

    def referentiel_support_statut?
      type_de_champ.referentiel? && !@champ.idle?
    end

    def pjs_statut?
      @champ.RIB? && !@champ.idle?
    end

    def dossier_link_support_statut?
      type_de_champ.dossier_link? && @champ.value.present?
    end

    def libelle
      @row_number.present? ? "[#{@row_number}] #{@champ.libelle}" : @champ.libelle
    end

    def statut_message
      case @champ.type_de_champ.type_champ
      when TypeDeChamp.type_champs[:siret]
        # TODO: use fetched? after T20251029backfillChampSiretExternalStateTask
        if @champ.etablissement && @champ.etablissement.entreprise_capital_social.present?
          { state: :info, text: t('.siret.fetched_with_capital', raison_sociale_or_name: raison_sociale_or_name(@champ.etablissement), forme_juridique: @champ.etablissement.entreprise_forme_juridique, capital_sociale: pretty_currency(@champ.etablissement.entreprise_capital_social)) }
        elsif @champ.etablissement && @champ.etablissement.entreprise_capital_social.blank?
          { state: :info, text: t('.siret.fetched', raison_sociale_or_name: raison_sociale_or_name(@champ.etablissement), forme_juridique: @champ.etablissement.entreprise_forme_juridique) }
        elsif @champ.external_error?
          { state: :warning, text: t('.siret.error', value: pretty_siret(@champ.external_id)) }
        elsif @champ.pending?
          { state: :info, text: t('.siret.pending', value: pretty_siret(@champ.external_id)) }
        end
      when TypeDeChamp.type_champs[:rna]
        { state: :info, text: t(".rna.data_fetched", title: @champ.title, address: @champ.full_address) }
      when TypeDeChamp.type_champs[:dossier_link]
        dossier = Dossier.visible_by_administration.find_by(id: @champ.value)
        if dossier.present?
          { state: :info, text: dossier.text_summary }
        elsif (deleted_dossier = @champ.deleted_dossier)
          { state: :warning, text: deleted_dossier_summary(deleted_dossier) }
        end
      when TypeDeChamp.type_champs[:referentiel]
        if @champ.pending?
          { state: :info, text: t(".referentiel.fetching") }
        elsif @champ.external_error?
          { state: :info, text: t(".referentiel.error", value: @champ.external_id) }
        elsif @champ.value.present?
          { state: :valid, text: t(".referentiel.success", value: @champ.value) }
        end
      when TypeDeChamp.type_champs[:piece_justificative]
        value_json = @champ.value_json
        iban = value_json&.dig('rib', 'iban')
        bank_name = value_json&.dig('rib', 'bank_name')

        if @champ.pending?
          { state: :info, text: t('.pj.info') }
        elsif @champ.external_error?
          { state: :warning, text: t('.pj.error') }
        elsif iban.nil?
          { state: :warning, text: t('.pj.warning') }
        else
          text = bank_name.present? ? t('.pj.valid_with_bank', iban:, bank_name:) : t('.pj.valid', iban:)
          { state: :valid, text: }
        end
      end
    end

    private

    def deleted_dossier_summary(deleted_dossier)
      t(".dossier_link.deleted",
        dossier_id: deleted_dossier.dossier_id,
        procedure: deleted_dossier.procedure.libelle,
        reason: deleted_dossier_reason(deleted_dossier),
        deleted_at: helpers.l(deleted_dossier.deleted_at.to_date))
    end

    def deleted_dossier_reason(deleted_dossier)
      t(".dossier_link.reasons.#{deleted_dossier.reason}")
    end
  end
end
