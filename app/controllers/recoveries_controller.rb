# frozen_string_literal: true

class RecoveriesController < ApplicationController
  before_action :ensure_pro_connect_is_used, except: [:nature, :post_nature, :support]
  before_action :ensure_collectivite_territoriale, except: [:nature, :post_nature, :support]

  def nature
  end

  def post_nature
    if nature_params == 'collectivite'
      redirect_to identification_recovery_path
    else
      redirect_to support_recovery_path(error: :other_nature)
    end
  end

  def identification
    @structure_name = structure_name
  end

  def post_identification
    # cipher previous_user email
    # to avoid leaks in the url
    ciphered_email = message_encryptor_service.encrypt_and_sign(previous_email, purpose: :agent_files_recovery, expires_in: 1.hour)

    redirect_to selection_recovery_path(ciphered_email:)
  end

  def selection
    @previous_email = message_encryptor_service.decrypt_and_verify(params[:ciphered_email], purpose: :agent_files_recovery) rescue nil

    previous_user = User.find_by(email: @previous_email)

    @recoverables = RecoveryService
      .recoverable_procedures(previous_user:, siret:)

    redirect_to support_recovery_path(error: :no_dossier) if @recoverables.empty?
  end

  # Security note: previous_email comes from params in plaintext here. This is NOT an IDOR
  # because the user already provides this email freely at the identification step.
  # The encryption between post_identification and selection only prevents email leakage
  # in the URL — it is not an access control mechanism.
  # The actual authorization is enforced by RecoveryService.recover_procedure! which
  # filters dossiers by the current instructeur's SIRET.
  def post_selection
    previous_user = User.find_by(email: previous_email)

    RecoveryService.recover_procedure!(previous_user:,
                          next_user: current_user,
                          siret:,
                          procedure_ids:)

    redirect_to terminee_recovery_path
  end

  def terminee
  end

  def support
  end

  private

  def nature_params = params[:nature]
  def siret = current_instructeur.last_pro_connect_information.siret
  def previous_email = params[:previous_email]
  def procedure_ids = params[:procedure_ids].map(&:to_i)

  def structure_name
    # we know that the structure exists because
    # of the ensure_collectivite_territoriale guard
    APIRechercheEntreprisesService.new.call(siret:).value![:nom_complet]
  end

  def ensure_pro_connect_is_used
    if current_instructeur&.last_pro_connect_information.nil?
      redirect_to support_recovery_path(error: :must_use_pro_connect)
    end
  end

  def ensure_collectivite_territoriale
    if !APIRechercheEntreprisesService.collectivite_territoriale?(siret:)
      redirect_to support_recovery_path(error: 'not_collectivite_territoriale')
    end
  end
end
