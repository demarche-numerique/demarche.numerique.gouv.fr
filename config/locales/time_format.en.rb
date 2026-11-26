# frozen_string_literal: true

{
  :en => {
    :time => {
      :formats => {
        veryshort: lambda { |time, _|
          if time.year == Date.current.year
            "%-d %b %H:%M"
          else
            "%-d %b %Y %H:%M"
          end
        },
        message_date: "%-d %B at %H:%M",
        message_date_with_year: "%-d %B %Y at %H:%M",
      },
    },

    date: {
      formats: {
        default: "%-d %B %Y",
      },
    },

    datetime: {
      distance_in_words: {
        x_weeks: {
          one: "1 week",
          other: "%{count} weeks",
        },
      },
    },
  },
}
