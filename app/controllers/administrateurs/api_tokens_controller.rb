# frozen_string_literal: true

module Administrateurs
  class APITokensController < AdministrateurController
    include ActionView::RecordIdentifier

    # Removing a procedure only narrows the token, it stays possible without ProConnect.
    skip_before_action :ensure_pro_connect_if_required!, only: :remove_procedure
    before_action :set_api_token, only: [:edit, :update, :destroy, :remove_procedure]
    before_action :set_api_token_form, only: [:nom, :autorisations, :securite, :create]

    def nom
    end

    def autorisations
      @libelle_id_procedures = libelle_id_procedures
    end

    def securite
    end

    def create
      if @api_token_form.invalid?
        return render_invalid_step
      end

      @api_token, @packed_token = APIToken.generate(current_administrateur, expires_at: @api_token_form.expires_at, **@api_token_form.token_attributes)

      @curl_command = curl_command(@packed_token, @api_token.procedure_ids.first)
    end

    def edit
      @libelle_id_procedures = libelle_id_procedures
    end

    def update
      @libelle_id_procedures = libelle_id_procedures

      h = {}

      if !params[:networks].nil?
        if invalid_network?
          @invalid_network_message = t('activemodel.errors.models.api_token_form.attributes.networks.invalid')
          return render :update, status: :unprocessable_content
        end

        # Tokens predating automatic IP pinning have no safety net: assign_first_ip!
        # skips them, so emptying their networks would leave them reachable from
        # anywhere until they expire. The newer ones re-pin themselves on the next
        # call, so they may be emptied.
        if !@api_token.requires_ip_filtering? && networks.empty?
          @invalid_network_message = t('.networks_required')
          @api_token.reload
          return render :update, status: :unprocessable_content
        end

        h[:authorized_networks] = networks
        flash.notice = t('.networks_updated')
      end

      if params[:name].present?
        h[:name] = params[:name]
        flash.notice = t('.renamed')
      end

      if params.key?(:follows_clones)
        h[:follows_clones] = params[:follows_clones] == '1'
      end

      @api_token.with_lock do
        if params[:restore_full_access].present?
          h[:allowed_procedure_ids] = nil
          h[:follows_clones] = false
          flash.notice = t('.full_access_restored')
        elsif params.key?(:procedure_to_add)
          procedure = current_administrateur.procedures.find_by(id: params[:procedure_to_add])

          if procedure.present?
            h[:allowed_procedure_ids] = (Array.wrap(@api_token.allowed_procedure_ids) + [procedure.id]).uniq
            flash.notice = t('.procedure_added', libelle: ERB::Util.html_escape(procedure.libelle))
          else
            flash.alert = t('.no_procedure_to_add')
          end
        end

        @api_token.update!(h)
      end

      render :update
    end

    def remove_procedure
      procedure = current_administrateur.procedures.with_discarded.find_by(id: params[:procedure_id])

      if procedure.present?
        @api_token.with_lock do
          remaining_ids = (@api_token.allowed_procedure_ids || current_administrateur.procedures.with_discarded.ids) - [procedure.id]
          @api_token.update!(allowed_procedure_ids: remaining_ids)
        end

        flash.notice = t('.procedure_removed', libelle: ERB::Util.html_escape(procedure.libelle))
      end

      @libelle_id_procedures = libelle_id_procedures
      render :update
    end

    def destroy
      @api_token.destroy

      render turbo_stream: turbo_stream.replace(dom_id(current_administrateur, :profil_api_token), Profile::APITokenCardComponent.new(unfold_expired: @api_token.expired?))
    end

    private

    def curl_command(packed_token, procedure_id)
      <<~EOF
        curl \\
        -H 'Content-Type: application/json' \\
        -H 'Authorization: Bearer #{packed_token}' \\
        --data '{ "query": "{ demarche(number: #{procedure_id}) { title } }" }' \\
        '#{api_v2_graphql_url}'
      EOF
    end

    def libelle_id_procedures
      current_administrateur
        .procedures
        .order(:libelle)
        .pluck(:libelle, :id)
        .map { |libelle, id| ["#{id} - #{libelle}", id] }
    end

    def render_invalid_step
      if @api_token_form.errors.include?(:name)
        render :nom, status: :unprocessable_content
      elsif @api_token_form.errors.include?(:allowed_procedure_ids)
        @libelle_id_procedures = libelle_id_procedures
        render :autorisations, status: :unprocessable_content
      else
        render :securite, status: :unprocessable_content
      end
    end

    def invalid_network?
      APIToken.parse_networks(params[:networks]).include?(nil)
    end

    def networks
      APIToken.parse_networks(params[:networks]).compact
    end

    def set_api_token
      @api_token = current_administrateur.api_tokens.find(params[:id])
    end

    def set_api_token_form
      @api_token_form =
        if params[:duplicate].present?
          APITokenForm.from_token(current_administrateur.api_tokens.find(params.expect(:duplicate)))
        else
          APITokenForm.new(api_token_form_params.merge(administrateur: current_administrateur))
        end
    end

    def api_token_form_params
      if params.key?(:api_token_form)
        params.expect(api_token_form: [:name, :duplicated_token_id, :target, :follows_clones, :access, :network_filtering, :networks, :lifetime, :custom_lifetime, procedure_ids: []])
      else
        {}
      end
    end
  end
end
