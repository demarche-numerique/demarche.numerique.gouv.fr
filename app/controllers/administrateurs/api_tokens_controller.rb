# frozen_string_literal: true

module Administrateurs
  class APITokensController < AdministrateurController
    include ActionView::RecordIdentifier

    before_action :set_api_token, only: [:edit, :update, :destroy, :remove_procedure]

    def nom
      @name = name
    end

    def autorisations
      @name = name
      @libelle_id_procedures = libelle_id_procedures
    end

    def securite
    end

    def create
      if params[:networkFiltering] == "customNetworks" && invalid_network?
        return redirect_to securite_admin_api_tokens_path(all_params.merge(invalidNetwork: true))
      end

      @api_token, @packed_token = APIToken.generate(current_administrateur)

      @api_token.update!(name:, write_access:,
                         allowed_procedure_ids:, authorized_networks:, expires_at:)

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
          @invalid_network_message = "vous devez entrer des adresses ipv4 ou ipv6 valides"
          return render :edit
        end

        if @api_token.eternal? && networks.empty?
          @invalid_network_message = "Vous ne pouvez pas supprimer les restrictions d’accès à l’API d’un jeton permanent."
          @api_token.reload
          return render :edit
        end

        h[:authorized_networks] = networks
      end

      if procedure_to_add.present?
        to_add = current_administrateur
          .procedure_ids
          .intersection([procedure_to_add])

        h[:allowed_procedure_ids] =
          (Array.wrap(@api_token.allowed_procedure_ids) + to_add).uniq
      end

      if params[:name].present?
        h[:name] = name
      end

      @api_token.update!(h)

      render :edit
    end

    def remove_procedure
      procedure_id = params[:procedure_id].to_i
      @api_token.allowed_procedure_ids =
        (@api_token.allowed_procedure_ids || @api_token.procedure_ids) - [procedure_id]
      @api_token.save!

      render turbo_stream: turbo_stream.remove("authorized_procedure_#{procedure_id}")
    end

    def destroy
      @api_token.destroy

      render turbo_stream: turbo_stream.remove(dom_id(@api_token))
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

    def all_params
      [:name, :access, :target, :targets, :networkFiltering, :networks, :lifetime, :customLifetime]
        .index_with { |param| params[param] }
    end

    def authorized_networks
      if params[:networkFiltering] == "customNetworks"
        networks
      else
        []
      end
    end

    def invalid_network?
      params[:networks]
        .split
        .any? do
          begin
            IPAddr.new(_1)
            false
          rescue
            true
          end
        end
    end

    def networks
      params[:networks]
        .split
        .map { begin IPAddr.new(_1) rescue nil end }
        .compact
    end

    def set_api_token
      @api_token = current_administrateur.api_tokens.find(params[:id])
    end

    def name
      params[:name]
    end

    def procedure_to_add
      params[:procedure_to_add]&.to_i
    end

    def write_access
      params[:access] == "read_write"
    end

    def allowed_procedure_ids
      if params[:target] == "custom"
        current_administrateur
          .procedure_ids
          .intersection(params[:targets].map(&:to_i))
      else
        nil
      end
    end

    def expires_at
      case params[:lifetime]
      in 'oneWeek'
        1.week.from_now.to_date
      in 'custom'
        [
          Date.parse(params[:customLifetime]),
          1.year.from_now,
        ].min
      in 'infinite' if authorized_networks.present?
        nil
      else
        1.week.from_now.to_date
      end
    end
  end
end
