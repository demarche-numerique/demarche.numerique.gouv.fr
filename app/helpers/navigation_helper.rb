# frozen_string_literal: true

module NavigationHelper
  def current_nav_section
    if procedure_management_section?
      'procedure_management'
    elsif user_support_section?
      'user_support'
    elsif downloads_section?
      'downloads'
    else
      'follow_up'
    end
  end

  private

  def procedure_management_section?
    return true if params[:action].in?(['administrateurs', 'history', 'stats', 'email_notifications', 'notification_preferences', 'deleted_dossiers'])
    return true if params[:controller] == 'instructeurs/groupe_instructeurs'

    false
  end

  def user_support_section?
    %w[email_usagers apercu].include?(params[:action])
  end

  def downloads_section?
    return true if params[:action].in?(['exports', 'export_templates'])
    return true if params[:controller] == 'instructeurs/archives'

    false
  end
end
