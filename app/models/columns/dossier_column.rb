# frozen_string_literal: true

class Columns::DossierColumn < Column
  def value(dossier)
    case table
    when 'self'
      dossier.public_send(column)
    when 'etablissement'
      dossier.etablissement.public_send(column)
    when 'individual'
      dossier.individual.public_send(column)
    when 'groupe_instructeur'
      dossier.groupe_instructeur.label
    when 'dossier_labels'
      dossier.labels.map(&:name).join(' ')
    when 'followers_instructeurs'
      dossier.followers_instructeurs.map(&:email).join(' ')
    when 'traitements'
      dossier.traitements.map(&:instructeur_email).join(' ')
    end
  end

  def dossier_column? = true

  def filtered_ids(dossiers, filter)
    case filter
    in { operator: 'before', value: Array }
      filtered_ids_before_value(dossiers, filter[:value])
    in { operator: 'after', value: Array }
      filtered_ids_after_value(dossiers, filter[:value])
    in { operator: 'between', value: Array }
      filtered_ids_for_date_range(dossiers, date_range(filter[:value]))
    in { operator: 'this_week' }
      filtered_ids_for_date_range(dossiers, Time.current.all_week)
    in { operator: 'this_month' }
      filtered_ids_for_date_range(dossiers, Time.current.all_month)
    in { operator: 'this_year' }
      filtered_ids_for_date_range(dossiers, Time.current.all_year)
    else
      filtered_ids_for_values(dossiers, filter[:value])
    end
  end

  def filtered_ids_before_value(dossiers, values)
    end_date = parse_datetime(values.first)

    return dossiers.ids if end_date.nil?

    filtered_ids_for_date_range(dossiers, ..end_date.beginning_of_day)
  end

  def filtered_ids_after_value(dossiers, values)
    start_date = parse_datetime(values.first)

    return dossiers.ids if start_date.nil?

    filtered_ids_for_date_range(dossiers, (start_date.end_of_day..))
  end

  def filtered_ids_for_date_range(dossiers, range)
    return dossiers.ids if range.begin.nil? && range.end.nil?

    dossiers.filter_by_datetimes_range(column, range).ids
  end

  def filtered_ids_for_values(dossiers, values)
    return dossiers.ids unless values.any?(&:present?)

    case table
    when 'self'
      if type == :date || type == :datetime
        dates = values
          .filter_map { parse_datetime(_1)&.beginning_of_day }

        dossiers.filter_by_datetimes(column, dates)
      elsif type == :integer
        dossiers.where("dossiers.#{column} IN (?)", values.filter_map { Integer(_1) rescue nil })
      else
        dossiers.where("dossiers.#{column} IN (?)", values)
      end
    when 'etablissement'
      if column == 'entreprise_date_creation'
        dates = values
          .filter_map { |v| v.to_date rescue nil }

        dossiers
          .includes(:etablissement)
          .where(etablissements: { column => dates })
      elsif type == :integer
        dossiers
          .includes(:etablissement)
          .where(etablissements: { column => values.filter_map { Integer(_1) rescue nil } })
      elsif type == :boolean
        dossiers
          .includes(:etablissement)
          .where(etablissements: { column => values })
      else
        dossiers
          .includes(:etablissement)
          .filter_ilike(table, column, values)
      end
    when 'followers_instructeurs'
      dossiers
        .includes(:followers_instructeurs)
        .joins('INNER JOIN users instructeurs_users ON instructeurs_users.id = instructeurs.user_id')
        .filter_ilike('instructeurs_users', :email, values) # ilike OK, user may want to search by *@domain
    when 'user', 'individual', 'traitements' # user_columns: [email], individual_columns: ['nom', 'prenom', 'gender']
      dossiers
        .includes(table)
        .filter_ilike(table, column, values) # ilike or where column == 'value' are both valid, we opted for ilike
    when 'dossier_labels'
      dossiers
        .joins(:dossier_labels)
        .where(dossier_labels: { label_id: values })
    when 'groupe_instructeur'
      dossiers
        .joins(:groupe_instructeur)
        .where(groupe_instructeur_id: values)
    when 'dossier_notifications'
      dossiers
        .joins(:dossier_notifications)
        .where(dossier_notifications: { notification_type: values })
    end.ids
  end
end
