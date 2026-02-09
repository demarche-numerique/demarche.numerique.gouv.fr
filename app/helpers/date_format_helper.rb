# frozen_string_literal: true

module DateFormatHelper
  MOIS = {
    fr: {
      1 => "janvier", 2 => "février", 3 => "mars", 4 => "avril",
          5 => "mai", 6 => "juin", 7 => "juillet", 8 => "août",
          9 => "septembre", 10 => "octobre", 11 => "novembre", 12 => "décembre",
    },
    en: {
      1 => "January", 2 => "February", 3 => "March", 4 => "April",
          5 => "May", 6 => "June", 7 => "July", 8 => "August",
          9 => "September", 10 => "October", 11 => "November", 12 => "December",
    },
  }.freeze

  MOIS_COURTS = {
    fr: {
      1 => "jan.", 2 => "fév.", 3 => "mars", 4 => "avr.",
          5 => "mai", 6 => "juin", 7 => "juil.", 8 => "août",
          9 => "sept.", 10 => "oct.", 11 => "nov.", 12 => "déc.",
    },
    en: {
      1 => "Jan", 2 => "Feb", 3 => "Mar", 4 => "Apr",
          5 => "May", 6 => "Jun", 7 => "Jul", 8 => "Aug",
          9 => "Sep", 10 => "Oct", 11 => "Nov", 12 => "Dec",
    },
  }.freeze

  JOURS = {
    fr: {
      0 => "dimanche", 1 => "lundi", 2 => "mardi", 3 => "mercredi",
          4 => "jeudi", 5 => "vendredi", 6 => "samedi",
    },
    en: {
      0 => "Sunday", 1 => "Monday", 2 => "Tuesday", 3 => "Wednesday",
          4 => "Thursday", 5 => "Friday", 6 => "Saturday",
    },
  }.freeze

  module_function

  def locale = I18n.locale

  # --- Formats date-only ---

  def long(date)
    d = date.to_date
    case locale
    when :fr then "#{format('%02d', d.day)} #{mois(d)} #{d.year}"
    when :en then "#{mois(d)} #{d.day}, #{d.year}"
    end
  end

  def short(date)
    date.to_date.strftime("%d/%m/%Y")
  end

  def dashed(date)
    date.to_date.strftime("%Y-%m-%d")
  end

  def month_year(date)
    d = date.to_date
    "#{mois(d)} #{d.year}"
  end

  def day_month_short(date)
    d = date.to_date
    case locale
    when :fr then "#{format('%02d', d.day)} #{mois_court(d)}"
    when :en then "#{mois_court(d)} #{d.day}"
    end
  end

  # --- Formats avec heure ---

  def long_with_time(datetime)
    case locale
    when :fr then "#{format('%02d', datetime.day)} #{mois(datetime)} #{datetime.year} à #{datetime.strftime('%H:%M')}"
    when :en then "#{mois(datetime)} #{datetime.day}, #{datetime.year} at #{datetime.strftime('%I:%M %p')}"
    end
  end

  def default(datetime)
    "#{format('%02d', datetime.day)} #{mois(datetime)} #{datetime.year} #{datetime.strftime('%H:%M')}"
  end

  def long_with_time_and_timezone(datetime)
    case locale
    when :fr then "#{format('%02d', datetime.day)} #{mois(datetime)} #{datetime.year} à #{datetime.strftime('%H:%M')} (#{datetime.strftime('%Z')})"
    when :en then "#{mois(datetime)} #{datetime.day}, #{datetime.year} at #{datetime.strftime('%I:%M %p')} (#{datetime.strftime('%Z')})"
    end
  end

  def short_with_time(datetime)
    datetime.strftime("%d/%m/%Y %H:%M")
  end

  def messagerie_date(datetime)
    case locale
    when :fr then "Le #{datetime.strftime('%d/%m/%Y %H:%M')}"
    when :en then datetime.strftime('%d/%m/%Y %H:%M')
    end
  end

  def human(datetime)
    case locale
    when :fr then "#{jour(datetime)} #{datetime.day} #{mois(datetime)} à #{datetime.strftime('%Hh%M')}"
    when :en then "#{jour(datetime)} #{datetime.day} #{mois(datetime)} at #{datetime.strftime('%I:%M %p')}"
    end
  end

  def message_date_with_year(datetime)
    day_str = datetime.day == 1 ? "1er" : datetime.day.to_s
    case locale
    when :fr then "le #{day_str} #{mois(datetime)} #{datetime.year} à #{datetime.strftime('%H h %M')}"
    when :en then "#{mois(datetime)} #{ordinalize(datetime.day)} #{datetime.year} at #{datetime.strftime('%H:%M')}"
    end
  end

  def veryshort(datetime)
    if datetime.year == Date.current.year
      case locale
      when :fr then datetime.strftime("%d/%m %H:%M")
      when :en then "#{datetime.day} #{mois_court(datetime)} #{datetime.strftime('%H:%M')}"
      end
    else
      case locale
      when :fr then datetime.strftime("%d/%m/%Y %H:%M")
      when :en then "#{datetime.day} #{mois_court(datetime)} #{datetime.year} #{datetime.strftime('%H:%M')}"
      end
    end
  end

  def message_date_without_time(datetime)
    datetime.strftime("%d/%m/%Y")
  end

  # --- Helpers privés ---

  def mois(date) = MOIS[locale][date.month]
  def mois_court(date) = MOIS_COURTS[locale][date.month]
  def jour(date) = JOURS[locale][date.wday]

  def ordinalize(number)
    suffix = case number % 10
    when 1 then number % 100 == 11 ? "th" : "st"
    when 2 then number % 100 == 12 ? "th" : "nd"
    when 3 then number % 100 == 13 ? "th" : "rd"
    else "th"
    end
    "#{number}#{suffix}"
  end
end
