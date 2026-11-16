# frozen_string_literal: true

module Users
  class ProfilController < UserController
    include FranceConnectConcern
    include ProfilContextConcern

    before_action :ensure_update_email_is_authorized, only: :update_email
    before_action :find_transfers, only: [:show]

    def show
      @france_connect_informations = FranceConnectInformation.where(user: current_user)
    end

    def update_email
      requested_user = User.find_by(email: requested_email)
      if requested_user.present? && dossiers_unreachable_from_session?
        alert = Current.user_session&.via_france_connect_plus? ? 'merge_another_identity' : 'merge_required'
        flash.alert = t("errors.messages.france_connect_plus.#{alert}")
      elsif requested_user.present?
        current_user.ask_for_merge(requested_user)

        flash.notice = t('devise.registrations.update_needs_confirmation')
      elsif update_with_lock(update_email_params)
        current_user.update(requested_merge_into: nil)

        flash.notice = t('devise.registrations.update_needs_confirmation')
      else
        flash.alert = current_user.errors.full_messages
      end

      redirect_to profil_path
    rescue ActiveRecord::RecordInvalid => e
      flash.alert = e.record.errors.full_messages
      redirect_to profil_path
    end

    def update_with_lock(params)
      current_user.with_lock do
        current_user.update!(params)
      end
    end

    # A merge moves the account's dossiers and invites: those of a procedure requiring
    # FranceConnect+ move from a session that may open them only
    def dossiers_unreachable_from_session?
      Dossier
        .where(id: current_user.dossiers).or(Dossier.where(id: current_user.dossiers_invites))
        .unreachable_from_session(Current.user_session)
        .exists?
    end

    def transfer_all_dossiers
      # A procedure that requires FranceConnect+ lets its dossiers go from a session that may open them only
      dossiers = current_user.dossiers.reachable_from_session(Current.user_session)
      unreachable_count = current_user.dossiers.unreachable_from_session(Current.user_session).count

      if unreachable_count.positive?
        store_location_for(:user, profil_path)
        flash.alert = france_connect_plus_left_out_message(unreachable_count)
      end

      if unreachable_count.zero? || dossiers.exists?
        transfer = DossierTransfer.initiate(next_owner_email, dossiers)

        if transfer.valid?
          flash.notice = t('.new_transfer', count: dossiers.count, email: next_owner_email)
        else
          flash.alert = [flash.alert, *transfer.errors.full_messages].compact
        end
      end

      redirect_to profil_path
    end

    def accept_merge
      users_requesting_merge.each { |user| current_user.merge(user) }
      users_requesting_merge.update_all(requested_merge_into_id: nil)

      flash.notice = "Vous avez absorbé le compte #{waiting_merge_emails.join(', ')}"
      redirect_to profil_path
    end

    def refuse_merge
      users = users_requesting_merge
      users.update_all(requested_merge_into_id: nil)

      flash.notice = 'La fusion a été refusé'
      redirect_to profil_path
    end

    def destroy_fci
      fci = current_user.france_connect_informations.find_by(id: params[:fci_id])
      return redirect_to profil_path if fci.nil?

      current_user.transaction do
        if Current.user_session.via_any_france_connect?
          SessionRegistrableConcern.swap_session!(current_user, warden, login_method: :password, reason: :france_connect_unlinked)
        end
        fci.destroy!
      end

      flash.notice = "Le compte FranceConnect de « #{fci.full_name} » ne peut plus accéder à vos dossiers"

      if france_connect_id_token?
        redirect_to france_connect_logout_url(callback: profil_url), allow_other_host: true
      else
        redirect_to profil_path
      end
    end

    def preferred_domain
      current_user.update_preferred_domain(request.host_with_port)

      head :no_content
    end

    private

    def find_transfers
      @waiting_merge_emails = waiting_merge_emails
      @waiting_transfers = current_user.dossiers.joins(:transfer).group('dossier_transfers.email').count.to_a
    end

    def waiting_merge_emails
      users_requesting_merge.pluck(:email)
    end

    def users_requesting_merge
      @requesting_merge ||= current_user.requested_merge_from
    end

    def ensure_update_email_is_authorized
      if (current_user.instructeur? || current_user.administrateur?) && !target_email_allowed?
        flash.alert = t('users.profil.ensure_update_email_is_authorized.email_not_allowed', contact_email: Current.contact_email, requested_email: requested_email)
        redirect_to profil_path
      end
    end

    def update_email_params
      params.require(:user).permit(:email)
    end

    def requested_email
      update_email_params[:email]
    end

    def target_email_allowed?
      requested_domain = downcased_domain(requested_email)
      return false if requested_domain.blank?

      requested_domain == downcased_domain(current_user.email)
    end

    def downcased_domain(email)
      Mail::Address.new(email).domain&.downcase
    rescue Mail::Field::IncompleteParseError
      nil
    end

    def next_owner_email
      params[:next_owner]
    end

    # A FranceConnect+ session of another identity than the dossiers' would loop through FranceConnect+
    def france_connect_plus_left_out_message(count)
      if Current.user_session&.via_france_connect_plus?
        t('users.profil.transfer_all_dossiers.left_out_another_identity', count:)
      else
        t('users.profil.transfer_all_dossiers.left_out_france_connect_plus_required', count:, url: france_connect_plus_path)
      end
    end
  end
end
