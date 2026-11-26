# frozen_string_literal: true

{
  :en => {
    :time => {
      :formats => {
        veryshort: lambda { |time, _|
          if time.year == Date.current.year
            "%-d %b %-l:%M%P"
          else
            "%-d %b %Y %-l:%M%P"
          end
        },
        message_date: "%-d %B at %-l:%M%P",
        message_date_with_year: "%-d %B %Y at %-l:%M%P",
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
