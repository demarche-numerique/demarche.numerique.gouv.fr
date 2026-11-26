# frozen_string_literal: true

# English follows the GOV.UK style guide: no leading zero, full month in text.
describe 'Date and time formats' do
  let(:date) { Date.new(2026, 12, 1) }
  let(:time) { Time.zone.local(2026, 12, 1, 14, 5) }

  {
    en: {
      date: { default: '1 December 2026', long: '1 December 2026', short: '1 Dec 2026', in_text: '1 December 2026', day_month_short: '1 Dec' },
      time: {
        default: '1 December 2026 14:05',
        long_with_time: '1 December 2026 at 14:05',
        short_with_time: '1 Dec 2026 at 14:05',
        messagerie_date: 'On 1 Dec 2026 14:05',
        human: 'Tuesday 1 December at 14h05',
      },
    },
    fr: {
      date: { default: '01 décembre 2026', long: '01 décembre 2026', short: '01/12/2026', in_text: '01/12/2026', day_month_short: '01 déc.' },
      time: {
        default: '01 décembre 2026 14:05',
        long_with_time: '01 décembre 2026 à 14:05',
        short_with_time: '01/12/2026 à 14:05',
        messagerie_date: 'Le 01/12/2026 14:05',
        human: 'mardi 1 décembre à 14h05',
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
