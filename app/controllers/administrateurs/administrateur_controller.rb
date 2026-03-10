# frozen_string_literal: true

module Administrateurs
  class AdministrateurController < ApplicationController
    include ProConnectSessionConcern

    before_action :authenticate_administrateur!
    before_action :alert_for_missing_siret_service
    before_action :alert_for_missing_service
    helper_method :administrateur_as_manager?

    def nav_bar_profile
      :administrateur
    end

    def retrieve_procedure
      id = params[:procedure_id] || params[:id]

      @procedure = current_administrateur.procedures.find(id)

      Sentry.configure_scope do |scope|
        scope.set_tags(procedure: @procedure.id)
      end

      ensure_pro_connect_if_required!
    rescue ActiveRecord::RecordNotFound
      flash.alert = 'Démarche inexistante'
      redirect_to admin_procedures_path, status: 404
    end

    def preload_revisions
      ProcedureRevisionPreloader.new(@procedure.revisions).all

      @procedure.association(:draft_revision).target = @procedure.revisions.find { _1.id == @procedure.draft_revision.id }
      if @procedure.published_revision
        @procedure.association(:published_revision).target = @procedure.revisions.find { _1.id == @procedure.published_revision.id }
      end
    end

    def ensure_not_super_admin!
      if administrateur_as_manager?
        redirect_back fallback_location: root_url, alert: "Interdit aux super admins", status: 403
      end
    end

    def ensure_pro_connect_if_required!
      return if @procedure.pro_connect_restriction_none?
      return if logged_in_with_pro_connect?

      flash.alert = "Vous devez vous connecter par ProConnect pour accéder à cette démarche"
      redirect_to new_user_session_path
    end

    private

    def administrateur_as_manager?
      id = params[:procedure_id] || params[:id]

      current_administrateur.administrateurs_procedures
        .exists?(procedure_id: id, manager: true)
    end

    def alert_for_missing_siret_service
      return if flash[:alert].present?

      procedures = missing_siret_services
      if procedures.any?
        errors = []
        errors << I18n.t('shared.procedures.no_siret')
        procedures.each do |p|
          errors << I18n.t('shared.procedures.add_siret_to_service_without_siret_html', link: edit_admin_service_path(p.service, procedure_id: p.id), nom: p.service.nom)
        end
        flash.now.alert = errors
      end
    end

    def missing_siret_services
      current_administrateur
        .procedures.publiees
        .joins(:service)
        .where(service: { siret: nil })
    end

    def alert_for_missing_service
      return if flash[:alert].present?

      procedures = missing_service
      if procedures.any?
        errors = []
        errors << I18n.t('shared.procedures.no_service')
        procedures.each do |p|
          errors << I18n.t('shared.procedures.add_service_html', link: admin_services_path(procedure_id: p.id), id: p.id)
        end
        flash.now.alert = errors
      end
    end

    def missing_service
      current_administrateur
        .procedures.publiees
        .where(service_id: nil)
    end
  end
end
