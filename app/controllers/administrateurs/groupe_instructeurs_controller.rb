# frozen_string_literal: true

module Administrateurs
  class GroupeInstructeursController < AdministrateurController
    include ActiveSupport::NumberHelper
    include EmailSanitizableConcern
    include Logic
    include GroupeInstructeursSignatureConcern
    include CsvParsingConcern

    before_action :ensure_not_super_admin!, only: [:add_instructeur]

    ITEMS_PER_PAGE = 25

    def index
      @procedure = procedure
      @groupes_instructeurs = paginated_groupe_instructeurs

      @instructeurs = paginated_instructeurs
      @available_instructeur_emails = available_instructeur_emails
      @maybe_typos = flash[:maybe_typos]
    end

    def options
      @procedure = procedure
      if params[:state] == 'choix' && @procedure.active_revision.simple_routable_types_de_champ.none?
        configurate_custom_routing
      end
    end

    def ajout
      redirect_to admin_procedure_groupe_instructeurs_path(procedure) if procedure.groupe_instructeurs.one?
      @procedure = procedure
      @groupes_instructeurs = paginated_groupe_instructeurs
    end

    def simple_routing
      @procedure = procedure
    end

    def create_simple_routing
      @procedure = procedure
      stable_id = params[:create_simple_routing][:stable_id].to_i

      tdc = @procedure.active_revision.simple_routable_types_de_champ.find { |tdc| tdc.stable_id == stable_id }

      case tdc.type_champ
      when TypeDeChamp.type_champs.fetch(:departements)
        tdc_options = APIGeoService.departement_options
        rule_operator = :ds_eq
        create_groups_from_territorial_tdc(tdc_options, stable_id, rule_operator)
      when TypeDeChamp.type_champs.fetch(:communes), TypeDeChamp.type_champs.fetch(:epci), TypeDeChamp.type_champs.fetch(:address)
        tdc_options = APIGeoService.departement_options
        rule_operator = :ds_in_departement
        create_groups_from_territorial_tdc(tdc_options, stable_id, rule_operator)
      when TypeDeChamp.type_champs.fetch(:regions)
        rule_operator = :ds_eq
        tdc_options = APIGeoService.region_options
        create_groups_from_territorial_tdc(tdc_options, stable_id, rule_operator)
      when TypeDeChamp.type_champs.fetch(:pays)
        rule_operator = :ds_eq
        tdc_options = APIGeoService.countries.map { ["#{_1[:code]} – #{_1[:name]}", _1[:code]] }
        create_groups_from_territorial_tdc(tdc_options, stable_id, rule_operator)
      when TypeDeChamp.type_champs.fetch(:drop_down_list)
        tdc_options = tdc.options_for_select
        create_groups_from_drop_down_list_tdc(tdc_options, stable_id)
      end

      if tdc.drop_down_other?
        routing_rule = ds_eq(champ_value(stable_id), constant(Champs::DropDownListChamp::OTHER))
        @procedure
          .groupe_instructeurs
          .find_or_create_by(label: 'Autre')
          .update(instructeurs: [current_administrateur.instructeur], routing_rule:)
      end

      @procedure.update_all_groupes_rule_statuses

      @procedure.toggle_routing
      defaut = @procedure.defaut_groupe_instructeur

      if tdc_options.none? { _1.first == defaut.label }
        new_defaut = @procedure.reload.groupe_instructeurs_but_defaut.first
        @procedure.update!(defaut_groupe_instructeur: new_defaut)
        reaffecter_all_dossiers_to_defaut_groupe
        defaut.instructeurs.each { new_defaut.add(_1) }
        defaut.destroy!
      end

      procedure.update!(routing_alert: true) if procedure.dossiers.state_en_construction_ou_instruction.any?

      flash[:routing_mode] = 'simple'

      redirect_to admin_procedure_groupe_instructeurs_path(@procedure)
    end

    def wizard
      if params[:choice][:state] == 'custom_routing'
        configurate_custom_routing
      elsif params[:choice][:state] == 'routage_simple'
        redirect_to simple_routing_admin_procedure_groupe_instructeurs_path
      end
    end

    def configurate_custom_routing
      procedure.defaut_groupe_instructeur.update!(label: 'Groupe 1 (à renommer et configurer)')
      procedure.groupe_instructeurs
        .create({ label: 'Groupe 2 (à renommer et configurer)', instructeurs: [current_administrateur.instructeur] })

      procedure.update_all_groupes_rule_statuses

      procedure.toggle_routing

      procedure.update!(routing_alert: true) if procedure.dossiers.state_en_construction_ou_instruction.any?

      flash[:routing_mode] = 'custom'

      redirect_to admin_procedure_groupe_instructeurs_path(procedure)
    end

    def destroy_all_groups_but_defaut
      reaffecter_all_dossiers_to_defaut_groupe
      procedure.groupe_instructeurs_but_defaut.each(&:destroy!)
      procedure.update!(routing_enabled: false, routing_alert: false)
      procedure.defaut_groupe_instructeur.update!(
        routing_rule: nil,
        label: GroupeInstructeur::DEFAUT_LABEL,
        closed: false,
        contact_information: nil
      )
      flash.notice = 'Tous les groupes instructeurs ont été supprimés'
      redirect_to admin_procedure_groupe_instructeurs_path(procedure)
    end

    def show
      @procedure = procedure
      @groupe_instructeur = groupe_instructeur
      @instructeurs = paginated_instructeurs
      @available_instructeur_emails = available_instructeur_emails
      @maybe_typos = flash[:maybe_typos]
    end

    def create
      @groupe_instructeur = procedure
        .groupe_instructeurs
        .new({ instructeurs: [current_administrateur.instructeur] }.merge(groupe_instructeur_params))

      if @groupe_instructeur.save
        procedure.toggle_routing
        routing_notice = " et le routage a été activé" if procedure.groupe_instructeurs.active.size == 2
        redirect_to admin_procedure_groupe_instructeur_path(procedure, @groupe_instructeur),
          notice: "Le groupe d’instructeurs « #{@groupe_instructeur.label} » a été créé#{routing_notice}."
      else
        @procedure = procedure
        @instructeurs = paginated_instructeurs
        @groupes_instructeurs = paginated_groupe_instructeurs

        flash.now[:alert] = @groupe_instructeur.errors.full_messages
        render :index
      end
    end

    def update
      @groupe_instructeur = groupe_instructeur

      if @groupe_instructeur.update(groupe_instructeur_params)
        procedure.toggle_routing
        redirect_to admin_procedure_groupe_instructeur_path(procedure, groupe_instructeur),
          notice: "Le nom est à présent « #{@groupe_instructeur.label} »."
      else
        @procedure = procedure
        @instructeurs = paginated_instructeurs
        @available_instructeur_emails = available_instructeur_emails

        flash.now[:alert] = @groupe_instructeur.errors.full_messages
        render :show
      end
    end

    def update_state
      @groupe_instructeur = procedure.groupe_instructeurs.find(params[:groupe_instructeur_id])

      @groupe_instructeur.update!(closed: params[:closed])
      state_for_notice = @groupe_instructeur.closed ? 'désactivé' : 'activé'
      redirect_to admin_procedure_groupe_instructeur_path(procedure, @groupe_instructeur),
        notice: "Le groupe « #{@groupe_instructeur.label} » est #{state_for_notice}."
    end

    def destroy
      @groupe_instructeur = groupe_instructeur

      if @groupe_instructeur.dossiers.present?
        flash[:alert] = "Impossible de supprimer un groupe avec des dossiers. Il faut le réaffecter avant"
      elsif procedure.groupe_instructeurs.one?
        flash[:alert] = "Suppression impossible : il doit y avoir au moins un groupe instructeur sur chaque procédure"
      elsif @groupe_instructeur.id == procedure.defaut_groupe_instructeur.id
        flash[:alert] = "Suppression impossible : le groupe « #{@groupe_instructeur.label} » est le groupe par défaut."
      else
        @groupe_instructeur.destroy!
        if procedure.groupe_instructeurs.active.one?
          procedure.toggle_routing
          procedure.update!(routing_alert: false)
          procedure.defaut_groupe_instructeur.update!(
            routing_rule: nil,
            label: GroupeInstructeur::DEFAUT_LABEL,
            closed: false,
            contact_information: nil
          )
          routing_notice = " et le routage a été désactivé"
        end
        flash[:notice] = "le groupe « #{@groupe_instructeur.label} » a été supprimé#{routing_notice}."
      end
      redirect_to admin_procedure_groupe_instructeurs_path(procedure)
    end

    def reaffecter_dossiers
      @procedure = procedure
      @groupe_instructeur = groupe_instructeur
      @groupes_instructeurs = @groupe_instructeur.other_groupe_instructeurs
    end

    def reaffecter
      target_group = procedure.groupe_instructeurs.find_by(id: params[:target_group])

      if target_group.present?
        groupe_instructeur.dossiers.find_each do |dossier|
          dossier.assign_to_groupe_instructeur(target_group, DossierAssignment.modes.fetch(:manual), current_administrateur)
        end

        flash[:notice] = t('administrateurs.groupe_instructeurs.reaffectation.success', group_label: groupe_instructeur.label, target_group_label: target_group.label)
        redirect_to admin_procedure_groupe_instructeurs_path(procedure)
      else
        flash[:alert] = t('administrateurs.groupe_instructeurs.reaffectation.error')
        redirect_to reaffecter_dossiers_admin_procedure_groupe_instructeur_path(procedure, groupe_instructeur)
      end
    end

    def reaffecter_all_dossiers_to_defaut_groupe
      procedure.groupe_instructeurs_but_defaut.each do |gi|
        gi.dossiers.find_each do |dossier|
          dossier.assign_to_groupe_instructeur(procedure.defaut_groupe_instructeur, DossierAssignment.modes.fetch(:auto), current_administrateur)
        end
      end
    end

    def add_instructeur
      emails_with_typos = JSON.parse(params[:emails_with_typos]) if params[:emails_with_typos]
      emails = params['emails'].presence || []
      emails.push(emails_with_typos).flatten! if emails_with_typos
      emails, maybe_typos = check_if_typo(emails)
      errors = Array.wrap(generate_emails_suggestions_message(maybe_typos))

      instructeurs, invalid_emails = groupe_instructeur.add_instructeurs(emails:)

      if invalid_emails.present?
        errors += [
          t('.wrong_address',
                    count: invalid_emails.size,
                    emails: invalid_emails.join(', ')),
        ]
      end

      if instructeurs.present?
        flash[:notice] = if procedure.routing_enabled?
          t('.assignment',
            count: instructeurs.size,
            emails: instructeurs.map(&:email).join(', '),
            groupe: groupe_instructeur.label)
        else
          "Les instructeurs ont bien été affectés à la démarche"
        end

        known_instructeurs, not_verified_instructeurs = instructeurs.partition { |instructeur| instructeur.user.email_verified_at }

        not_verified_instructeurs.filter(&:should_receive_email_activation?).each do
          InstructeurMailer.confirm_and_notify_added_instructeur(_1, groupe_instructeur, current_administrateur.email).deliver_later
        end

        if known_instructeurs.present?
          GroupeInstructeurMailer
            .notify_added_instructeurs(groupe_instructeur, known_instructeurs, current_administrateur.email)
            .deliver_later
        end
      end

      flash[:alert] = errors.join(". ") if !errors.empty?

      @procedure = procedure
      @instructeurs = paginated_instructeurs
      @available_instructeur_emails = available_instructeur_emails

      if procedure.routing_enabled?
        @groupe_instructeur = groupe_instructeur
        redirect_to admin_procedure_groupe_instructeur_path(@procedure, @groupe_instructeur), flash: { maybe_typos: }
      else
        @groupes_instructeurs = paginated_groupe_instructeurs
        redirect_to admin_procedure_groupe_instructeurs_path(@procedure), flash: { maybe_typos: }
      end
    end

    def remove_instructeur
      if groupe_instructeur.instructeurs.one?
        flash[:alert] = "Suppression impossible : il doit y avoir au moins un instructeur dans le groupe"
      else
        instructeur = groupe_instructeur.instructeurs.find_by(id: instructeur_id)

        if groupe_instructeur.remove(instructeur)
          flash[:notice] = if instructeur.in?(procedure.instructeurs)
            "L’instructeur « #{instructeur.email} » a été retiré du groupe."
          else
            "L’instructeur a bien été désaffecté de la démarche"
          end
          GroupeInstructeurMailer
            .notify_removed_instructeur(groupe_instructeur, instructeur, current_administrateur.email)
            .deliver_later
        else
          flash[:alert] = if procedure.routing_enabled?
            if instructeur.present?
              "L’instructeur « #{instructeur.email} » n’est pas dans le groupe."
            else
              "L’instructeur n’est pas dans le groupe."
            end
          else
            "L’instructeur n’est pas affecté à la démarche"
          end
        end
      end

      if procedure.routing_enabled?
        redirect_to admin_procedure_groupe_instructeur_path(procedure, groupe_instructeur)
      else
        redirect_to admin_procedure_groupe_instructeurs_path(procedure)
      end
    end

    def update_instructeurs_self_management_enabled
      procedure.update!(instructeurs_self_management_enabled_params)

      redirect_to options_admin_procedure_groupe_instructeurs_path(procedure),
      notice: "L’autogestion des instructeurs est #{procedure.instructeurs_self_management_enabled? ? "activée" : "désactivée"}."
    end

    def import
      if !CSV_ACCEPTED_CONTENT_TYPES.include?(csv_file.content_type) && !CSV_ACCEPTED_CONTENT_TYPES.include?(marcel_content_type)
        flash[:alert] = "Importation impossible : veuillez importer un fichier CSV"

      elsif csv_file.size > CSV_MAX_SIZE
        flash[:alert] = "Importation impossible : le poids du fichier est supérieur à #{number_to_human_size(CSV_MAX_SIZE)}"

      else
        csv_content = parse_csv(csv_file)

        if csv_content.first.has_key?("groupe") && csv_content.first.has_key?("email")
          groupes_emails = csv_content.map { |r| r.to_h.slice('groupe', 'email') }

          added_instructeurs_by_group, invalid_emails = InstructeursImportService.import_groupes(procedure, groupes_emails)

          added_instructeurs_by_group.each do |groupe, added_instructeurs|
            if added_instructeurs.present?
              notify_instructeurs(groupe, added_instructeurs)
            end
            flash_message_for_import(invalid_emails)
          end

        elsif csv_content.first.has_key?("email") && !csv_content.map(&:to_h).first.keys.many? && procedure.groupe_instructeurs.one?
          instructors_emails = csv_content.map(&:to_h)

          added_instructeurs, invalid_emails = InstructeursImportService.import_instructeurs(procedure, instructors_emails)
          if added_instructeurs.present?
            notify_instructeurs(groupe_instructeur, added_instructeurs)
          end
          flash_message_for_import(invalid_emails)
        else
          flash_message_for_invalid_csv
        end
        redirect_to admin_procedure_groupe_instructeurs_path(procedure)
      end
    end

    def export_groupe_instructeurs
      groupe_instructeurs = procedure.groupe_instructeurs

      data = CSV.generate(headers: true) do |csv|
        column_names = ["Groupe", "Email"]
        csv << column_names
        groupe_instructeurs.each do |gi|
          gi.instructeurs.each do |instructeur|
            csv << [gi.label, instructeur.email]
          end
        end
      end

      respond_to do |format|
        format.csv { send_data data, filename: "#{procedure.id}-groupe-instructeurs-#{Date.today}.csv" }
      end
    end

    def bulk_route
      BulkRouteJob.perform_later(procedure)

      flash[:notice] = "Le routage des dossiers est lancé."

      redirect_to admin_procedure_groupe_instructeurs_path(procedure)
    end

    private

    def closed_params?
      params[:closed] == "1"
    end

    def procedure
      current_administrateur
        .procedures
        .includes(:groupe_instructeurs)
        .find(params[:procedure_id])
    end

    def groupe_instructeur
      if params[:id].present?
        procedure.groupe_instructeurs.find(params[:id])
      else
        procedure.defaut_groupe_instructeur
      end
    end

    def instructeur_id
      params[:instructeur][:id]
    end

    def groupe_instructeur_params
      params.require(:groupe_instructeur).permit(:label)
    end

    def signature_params
      params.require(:groupe_instructeur).permit(:signature)
    end

    def paginated_groupe_instructeurs
      groupes = if params[:q].present?
        query = ActiveRecord::Base.sanitize_sql_like(params[:q])

        procedure
          .groupe_instructeurs
          .where('unaccent(label) ILIKE unaccent(?)', "%#{query}%")
      else
        procedure.groupe_instructeurs
      end

      if params[:filter] == '1'
        groupes = Kaminari.paginate_array(groupes.filter(&:routing_to_configure?))
      end

      groupes
        .page(params[:page])
        .per(ITEMS_PER_PAGE)
    end

    def paginated_instructeurs
      groupe_instructeur
        .instructeurs
        .page(params[:page])
        .per(ITEMS_PER_PAGE)
        .order(:email)
    end

    def available_instructeur_emails
      all = current_administrateur.instructeurs.map(&:email)
      assigned = groupe_instructeur.instructeurs.map(&:email)
      (all - assigned).sort
    end

    def csv_file
      params[:csv_file]
    end

    def marcel_content_type
      Marcel::MimeType.for(csv_file.read, name: csv_file.original_filename, declared_type: csv_file.content_type)
    end

    def instructeurs_self_management_enabled_params
      params.require(:procedure).permit(:instructeurs_self_management_enabled)
    end

    def hide_instructeurs_email_params
      params.require(:procedure).permit(:hide_instructeurs_email)
    end

    def routing_enabled_params
      { routing_enabled: params.require(:routing) == 'enable' }
    end

    def flash_message_for_import(result)
      if result.blank?
        flash[:notice] = "La liste des instructeurs a été importée avec succès"
      else
        flash[:alert] = "Import terminé. Cependant les adresses électroniques suivantes ne sont pas prises en compte : #{result.join(', ')}"
      end
    end

    def flash_message_for_invalid_csv
      flash[:alert] = "Importation impossible, veuillez importer un csv suivant #{view_context.link_to('ce modèle', "/csv/import-instructeurs-test.csv")} pour une procédure sans routage ou #{view_context.link_to('celui-ci', "/csv/#{I18n.locale}/import-groupe-test.csv")} pour une procédure routée"
    end

    def create_groups_from_territorial_tdc(tdc_options, stable_id, rule_operator)
      tdc_options.each do |label, code|
        routing_rule = send(rule_operator, champ_value(stable_id), constant(code))

        @procedure
          .groupe_instructeurs
          .find_or_create_by(label: label)
          .update(instructeurs: [current_administrateur.instructeur], routing_rule:)
      end
    end

    def create_groups_from_drop_down_list_tdc(tdc_options, stable_id)
      tdc_options.each do |label, _|
        routing_rule = ds_eq(champ_value(stable_id), constant(label))
        @procedure
          .groupe_instructeurs
          .find_or_create_by(label: label)
          .update(instructeurs: [current_administrateur.instructeur], routing_rule:)
      end
    end

    def notify_instructeurs(groupe, added_instructeurs)
      known_instructeurs, new_instructeurs = added_instructeurs.partition { |instructeur| instructeur.user.email_verified_at }

      new_instructeurs.each { InstructeurMailer.confirm_and_notify_added_instructeur(_1, groupe, current_administrateur.email).deliver_later }

      if known_instructeurs.present?
        GroupeInstructeurMailer
          .notify_added_instructeurs(groupe, known_instructeurs, current_administrateur.email)
          .deliver_later
      end
    end
  end
end
