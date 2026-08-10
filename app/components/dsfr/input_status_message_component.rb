# frozen_string_literal: true

module Dsfr
  class InputStatusMessageComponent < ApplicationComponent
    include EtablissementHelper
    delegate :type_de_champ, to: :@champ
    delegate :prefilled?, to: :@champ

    def initialize(champ:, champ_component: nil, row_number: nil, as_announcement: false)
      @errors_on_attribute = champ_component&.errors_on_attribute?
      @error_full_messages = champ_component&.error_full_messages || []
      @error_id = champ_component ? champ.error_id(champ_component.attribute) : nil
      @champ = champ
      @row_number = row_number
      @as_announcement = as_announcement
    end

    # True when the champ has an external/async status message to surface.
    # Validation errors and the static "prefilled" notice are handled separately
    # (they are not produced by statut_message).
    def status_announcement?
      statutable? && statut_message.present?
    end

    def statutable?
      siret_support_status? ||
      rna_support_statut? ||
      rnf_support_statut? ||
      referentiel_support_statut? ||
      address_support_statut? ||
      dossier_link_support_statut? ||
      prefilled? ||
      pjs_statut?
    end

    def siret_support_status?
      type_de_champ.siret? && @champ.external_id.present?
    end

    def rna_support_statut?
      type_de_champ.rna? && @champ.external_id.present?
    end

    def rnf_support_statut?
      type_de_champ.rnf? && @champ.external_id.present?
    end

    def referentiel_support_statut?
      type_de_champ.referentiel? && (!@champ.idle? || type_de_champ.referentiel.blank?)
    end

    def pjs_statut?
      (@champ.rib? || @champ.justificatif_domicile? || @champ.avis_impot?) && !@champ.idle?
    end

    def address_support_statut?
      type_de_champ.address? && !@champ.idle?
    end

    def dossier_link_support_statut?
      type_de_champ.dossier_link? && @champ.value.present?
    end

    def libelle
      @row_number.present? ? "[#{@row_number}] #{@champ.libelle_for_error}" : @champ.libelle_for_error
    end

    def statut_message
      @statut_message ||= compute_statut_message
    end

    private

    def compute_statut_message
      case @champ.type_de_champ.type_champ
      when TypeDeChamp.type_champs[:siret]
        # TODO: use fetched? after T20251029backfillChampSiretExternalStateTask
        if @champ.etablissement && @champ.etablissement.entreprise_capital_social.present?
          { state: :info, text: t('.siret.fetched_with_capital', raison_sociale_or_name: displayable_raison_sociale_or_name(@champ.etablissement), forme_juridique: @champ.etablissement.entreprise_forme_juridique, capital_sociale: pretty_currency(@champ.etablissement.entreprise_capital_social)) }
        elsif @champ.etablissement && @champ.etablissement.entreprise_capital_social.blank?
          { state: :info, text: t('.siret.fetched', raison_sociale_or_name: displayable_raison_sociale_or_name(@champ.etablissement), forme_juridique: @champ.etablissement.entreprise_forme_juridique) }
        elsif @champ.external_error?
          { state: :warning, text: t('.siret.error', value: pretty_siret(@champ.external_id)) }
        elsif @champ.pending?
          { state: :info, text: t('.siret.pending', value: pretty_siret(@champ.external_id)) }
        end
      when TypeDeChamp.type_champs[:rna]
        if @champ.pending?
          { state: :info, text: t(".rna.pending", value: @champ.external_id) }
        elsif @champ.external_error?
          { state: :warning, text: t(".rna.error") }
        elsif @champ.value.present?
          { state: :info, text: t(".rna.success", title: @champ.title, address: @champ.full_address) }
        end
      when TypeDeChamp.type_champs[:rnf]
        if @champ.pending?
          { state: :info, text: t(".rnf.pending") }
        elsif @champ.external_error?
          { state: :warning, text: t(".rnf.error") }
        elsif @champ.data.present?
          { state: :info, text: t(".rnf.success", title: @champ.title, address: @champ.full_address) }
        end
      when TypeDeChamp.type_champs[:dossier_link]
        dossier = Dossier.find_by(id: @champ.value)
        deleted_dossier = DeletedDossier.find_by(dossier_id: @champ.value) if dossier.nil?
        if deleted_dossier.present?
          {
            state: :info, text: t('shared.champs.dossier_link.hidden',
                                       depose_at: l(deleted_dossier.depose_at),
                                       procedure_libelle: deleted_dossier.procedure.libelle,
                                       hidden_at: l(deleted_dossier.deleted_at.to_date)),
          }
        elsif dossier.present?
          if dossier.hidden_by_expired_at.present?
            {
              state: :info, text: t('shared.champs.dossier_link.expired',
                                         depose_at: l(dossier.depose_at.to_date),
                                         procedure_libelle: dossier.procedure.libelle,
                                         expired_at: l(dossier.hidden_by_expired_at.to_date)),
            }
          elsif dossier.hidden_by_user_at.present?
            {
              state: :info, text: t('shared.champs.dossier_link.hidden',
                                         depose_at: l(dossier.depose_at.to_date),
                                         procedure_libelle: dossier.procedure.libelle,
                                         hidden_at: l(dossier.hidden_by_user_at.to_date)),
            }
          else
            { state: :info, text: dossier.text_summary }
          end
        end
      when TypeDeChamp.type_champs[:referentiel]
        if type_de_champ.referentiel.blank?
          { state: :error, text: t(".referentiel.not_configured") }
        elsif @champ.pending?
          { state: :info, text: t(".referentiel.fetching") }
        elsif @champ.external_error?
          { state: :warning, text: t(".referentiel.error", value: @champ.external_id) }
        elsif @champ.value.present?
          { state: :valid, text: t(".referentiel.success", value: @champ.value) }
        end
      when TypeDeChamp.type_champs[:address]
        if @champ.pending?
          { state: :info, text: t(".address.fetching", value: @champ.external_id) }
        elsif @champ.external_error?
          { state: :warning, text: t(".address.error") }
        end
      when TypeDeChamp.type_champs[:piece_justificative]
        if @champ.pending?
          { state: :info, text: t('.pj.info') }
        elsif @champ.external_error?
          { state: :warning, text: t('.pj.error') }
        elsif @champ.justificatif_domicile?
          justif = @champ.ocr_result
          if justif&.two_ddoc
            { state: :valid, text: t('.pj.justif_domicile.valid_html', beneficiary: justif.beneficiary, address: justif.label, issue_date: l(justif.issue_date)) }
          else
            { state: :warning, text: t('.pj.justif_domicile.warning') }
          end
        elsif @champ.avis_impot?
          avis = @champ.ocr_result
          if avis&.two_ddoc
            { state: :valid, text: t('.pj.avis_impot.valid_html', declarant: avis.declarant_1, reference: avis.reference_avis, annee: avis.annee_des_revenus) }
          else
            { state: :warning, text: t('.pj.avis_impot.warning') }
          end
        else
          value_json = @champ.value_json
          iban = value_json&.dig('rib', 'iban')
          bank_name = value_json&.dig('rib', 'bank_name')

          if iban.nil?
            { state: :warning, text: t('.pj.warning') }
          else
            text = bank_name.present? ? t('.pj.valid_with_bank', iban:, bank_name:) : t('.pj.valid', iban:)
            { state: :valid, text: }
          end
        end
      end
    end

    def displayable_raison_sociale_or_name(etablissement)
      if etablissement.diffusable_commercialement
        raison_sociale_or_name(etablissement)
      else
        t('non_diffusible', scope: 'views.shared.dossiers.identite_entreprise')
      end
    end
  end
end
