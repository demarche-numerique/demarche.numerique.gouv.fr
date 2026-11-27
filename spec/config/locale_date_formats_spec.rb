# frozen_string_literal: true

# English follows the GOV.UK style guide: no leading zero, full month in text, 12-hour clock.
describe 'Date and time formats' do
  let(:date) { Date.new(2026, 12, 1) }
  let(:time) { Time.zone.local(2026, 12, 1, 14, 5) }

  before { travel_to(Time.zone.local(2026, 12, 2)) }

  {
    en: {
      date: { long: '1 December 2026', short: '1 Dec 2026', in_text: '1 December 2026', day_month_short: '1 Dec' },
      time: {
        default: '1 December 2026 2:05pm',
        long_with_time: '1 December 2026 at 2:05pm',
        short_with_time: '1 Dec 2026 at 2:05pm',
        messagerie_date: 'On 1 Dec 2026 2:05pm',
        human: 'Tuesday 1 December at 2:05pm',
        time_only: '2:05pm',
        veryshort: '1 Dec 2:05pm',
        message_date: '1 December at 2:05pm',
        message_date_with_year: '1 December 2026 at 2:05pm',
      },
    },
    fr: {
      date: { long: '01 décembre 2026', short: '01/12/2026', in_text: '01/12/2026', day_month_short: '01 déc.' },
      time: {
        default: '01 décembre 2026 14:05',
        long_with_time: '01 décembre 2026 à 14:05',
        short_with_time: '01/12/2026 à 14:05',
        messagerie_date: 'Le 01/12/2026 14:05',
        human: 'mardi 1 décembre à 14h05',
        time_only: '14:05',
        veryshort: '01/12 14:05',
        message_date: "le 1er décembre à 14\u00A0h\u00A005",
        message_date_with_year: "le 1er décembre 2026 à 14\u00A0h\u00A005",
      },
    },
  }.each do |locale, formats|
    context "in #{locale}" do
      formats[:date].each do |format, expected|
        it("formats a date as #{format}") { expect(I18n.l(date, format:, locale:)).to eq(expected) }
      end

      formats[:time].each do |format, expected|
        it("formats a time as #{format}") { expect(I18n.l(time, format:, locale:)).to eq(expected) }
      end
    end
  end
end
