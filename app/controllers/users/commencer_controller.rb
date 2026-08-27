# frozen_string_literal: true

module Users
  class CommencerController < ApplicationController
    include ProConnectSessionConcern

    layout 'procedure_context'

    def commencer
      @procedure = retrieve_procedure

      return procedure_not_found if @procedure.blank?

      return redirect_to commencer_path(@procedure.path, **extra_query_params), status: :moved_permanently if @procedure.path && @procedure.path != params[:path]

      @revision = params[:test] ? @procedure.draft_revision : @procedure.active_revision

      if params[:prefill_token].present? || commencer_page_is_reloaded?
        retrieve_prefilled_dossier(params[:prefill_token] || session[:prefill_token])
      elsif prefill_params_present?
        build_prefilled_dossier
      end

      if user_signed_in?
        set_prefilled_dossier_ownership if @prefilled_dossier&.orphan?
        check_prefilled_dossier_ownership if @prefilled_dossier

        revision = @revision.draft? ? @revision : @procedure.revisions.where.not(id: @procedure.draft_revision_id)
        @dossiers = current_user.dossiers.select(:id, :created_at, :depose_at, :state).visible_by_user.where(revision:).order(created_at: :desc).to_a
        @drafts, @not_drafts = @dossiers.partition(&:brouillon?)
        @preview_dossiers = @dossiers.take(3)
      end

      store_user_location!(@procedure)

      render 'commencer/show'
    end

    def commencer_test
      redirect_to commencer_path(params[:path], **extra_query_params)
    end

    def dossier_vide_pdf
      @procedure = retrieve_procedure_with_closed
      return procedure_not_found if @procedure.blank? || @procedure.brouillon?

      generate_empty_pdf(@procedure.published_revision)
    end

    def dossier_vide_pdf_test
      @procedure = retrieve_procedure_with_closed
      return procedure_not_found if @procedure.blank?

      generate_empty_pdf(@procedure.draft_revision)
    end

    def sign_in
      @procedure = retrieve_procedure
      return procedure_not_found if @procedure.blank?

      store_user_location!(@procedure)
      redirect_to new_user_session_path
    end

    def sign_up
      @procedure = retrieve_procedure
      return procedure_not_found if @procedure.blank?

      store_user_location!(@procedure)
      redirect_to new_user_registration_path
    end

    def france_connect
      @procedure = retrieve_procedure
      return procedure_not_found if @procedure.blank?

      store_user_location!(@procedure)
      redirect_to france_connect_path
    end

    def pro_connect
      @procedure = retrieve_procedure
      return procedure_not_found if @procedure.blank?

      store_user_location!(@procedure)
      redirect_to pro_connect_path
    end

    def procedure_for_help
      retrieve_procedure
    end

    def nav_bar_profile = nav_bar_user_or_guest

    def closing_details
      @procedure = Procedure.find_with_path(params[:path]).first

      return procedure_not_found if @procedure.blank?

      redirect_to commencer_path(params[:path]) and return if !@procedure.close?

      render 'closing_details', layout: 'procedure_unavailable'
    end

    def not_found
      render 'not_found', layout: 'procedure_unavailable'
    end

    private

    def commencer_page_is_reloaded?
      session[:prefill_token].present? && session[:prefill_params_digest] == PrefillChamps.digest(params)
    end

    def prefill_params_present?
      params.keys.find { ['champ', 'identite'].include?(_1.split('_').first) }
    end

    def retrieve_procedure
      Procedure.publiees.or(Procedure.brouillons).with_active_revision.find_with_path(params[:path]).first
    end

    def retrieve_procedure_with_closed
      Procedure.publiees.or(Procedure.brouillons).or(Procedure.closes).with_active_revision.order(published_at: :desc).find_with_path(params[:path]).first
    end

    def build_prefilled_dossier
      @prefilled_dossier = Dossier.new(
        revision: @revision,
        state: Dossier.states.fetch(:brouillon),
        prefilled: true
      )
      @prefilled_dossier.build_default_values
      if @prefilled_dossier.save
        @prefilled_dossier.prefill!(PrefillChamps.new(@prefilled_dossier, params.to_unsafe_h).to_a, PrefillIdentity.new(@prefilled_dossier, params.to_unsafe_h).to_h)
      end
      session[:prefill_token] = @prefilled_dossier.prefill_token
      session[:prefill_params_digest] = PrefillChamps.digest(params)
    end

    def retrieve_prefilled_dossier(prefill_token)
      @prefilled_dossier = Dossier.state_brouillon.prefilled.find_by!(prefill_token: prefill_token)
    end

    # The prefilled dossier is not owned yet, and the user is signed in: they become the new owner
    def set_prefilled_dossier_ownership
      @prefilled_dossier.update!(user: current_user)
      pro_connect = logged_in_with_pro_connect?
      source = IdentityPrefillSource.new(dossier: @prefilled_dossier, pro_connect:)
      if @prefilled_dossier.procedure.for_individual? && !source.none?
        @prefilled_dossier.prefill_individual_from_identity_provider(pro_connect:)
        @prefilled_dossier.individual.save!
      end
      DossierMailer.with(dossier: @prefilled_dossier).notify_new_draft.deliver_later
      Ami::CreateNotificationService.call(dossier: @prefilled_dossier)
    end

    # The prefilled dossier is owned by another user: raise an exception
    def check_prefilled_dossier_ownership
      raise ActiveRecord::RecordNotFound unless @prefilled_dossier.owned_by?(current_user)
    end

    def procedure_not_found
      procedure = Procedure.find_with_path(params[:path]).first

      if procedure&.replaced_by_procedure && procedure.replaced_by_procedure != procedure
        redirect_to commencer_path(procedure.replaced_by_procedure.path, **extra_query_params)
        return
      elsif procedure&.close?
        redirect_to closing_details_path(procedure.path)
        return
      else
        flash.alert = t('errors.messages.procedure_not_found')
        redirect_to not_found_path(params[:path])
      end
    end

    def store_user_location!(procedure)
      store_location_for(:user, commencer_path(procedure.path, **extra_query_params))
    end

    def generate_empty_pdf(revision)
      @revision = revision
      @procedure = revision.procedure
      filename = "#{@procedure.libelle}.pdf"

      if @procedure.feature_enabled?(:dossier_vide_weasyprint)
        send_data(dossier_vide_weasyprint_pdf(revision), filename:, type: 'application/pdf')
      else
        send_data(render_dossier_vide_prawn, filename:)
      end
    rescue StandardError => e
      # Any failure of the new WeasyPrint path falls back to the proven Prawn rendering.
      Sentry.capture_exception(e, extra: { procedure_id: @procedure.id })
      send_data(render_dossier_vide_prawn, filename:)
    end

    # A published PDF is cached in Active Storage, behind a cache key built from
    # everything it depends on. The draft ("test") PDF is never cached.
    def dossier_vide_weasyprint_pdf(revision)
      return render_dossier_vide_weasyprint(revision) if revision.draft?

      procedure = revision.procedure
      cache_key = procedure.dossier_vide_pdf_cache_key_for(revision)

      return procedure.dossier_vide_pdf.download if procedure.dossier_vide_pdf_fresh?(cache_key)

      render_dossier_vide_weasyprint(revision)
        .tap { procedure.store_dossier_vide_pdf(it, cache_key:) }
    end

    def render_dossier_vide_weasyprint(revision)
      html = render_to_string(
        Dossiers::DossierVidePdfComponent.new(revision:),
        layout: 'dossier_vide_pdf',
        formats: [:html]
      )

      options = {
        procedure_id: revision.procedure.id,
        path: request.path,
      }

      WeasyprintService.generate_pdf(html, options)
    end

    def render_dossier_vide_prawn
      render_to_string(template: 'dossiers/dossier_vide', formats: [:pdf])
    end
  end
end
