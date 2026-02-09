# frozen_string_literal: true

RSpec.describe DateFormatHelper do
  let(:date) { Date.new(2024, 2, 15) }
  let(:datetime) { Time.zone.local(2024, 2, 15, 14, 30) } # jeudi / Thursday

  describe "date-only formats" do
    describe ".long" do
      it "formats in French" do
        I18n.with_locale(:fr) do
          expect(DateFormatHelper.long(date)).to eq("15 février 2024")
        end
      end

      it "formats in English" do
        I18n.with_locale(:en) do
          expect(DateFormatHelper.long(date)).to eq("February 15, 2024")
        end
      end

      it "converts datetime to date automatically" do
        I18n.with_locale(:fr) do
          expect(DateFormatHelper.long(datetime)).to eq("15 février 2024")
        end
      end

      it "zero-pads single-digit days in French" do
        I18n.with_locale(:fr) do
          expect(DateFormatHelper.long(Date.new(2026, 1, 1))).to eq("01 janvier 2026")
        end
      end

      it "does not zero-pad days in English" do
        I18n.with_locale(:en) do
          expect(DateFormatHelper.long(Date.new(2026, 1, 1))).to eq("January 1, 2026")
        end
      end
    end

    describe ".short" do
      it "formats identically in both locales" do
        expect(DateFormatHelper.short(date)).to eq("15/02/2024")
      end

      it "converts datetime to date automatically" do
        expect(DateFormatHelper.short(datetime)).to eq("15/02/2024")
      end
    end

    describe ".dashed" do
      it "formats identically in both locales" do
        expect(DateFormatHelper.dashed(date)).to eq("2024-02-15")
      end
    end

    describe ".month_year" do
      it "formats in French" do
        I18n.with_locale(:fr) do
          expect(DateFormatHelper.month_year(date)).to eq("février 2024")
        end
      end

      it "formats in English" do
        I18n.with_locale(:en) do
          expect(DateFormatHelper.month_year(date)).to eq("February 2024")
        end
      end
    end

    describe ".day_month_short" do
      it "formats in French (day first)" do
        I18n.with_locale(:fr) do
          expect(DateFormatHelper.day_month_short(date)).to eq("15 fév.")
        end
      end

      it "formats in English (month first)" do
        I18n.with_locale(:en) do
          expect(DateFormatHelper.day_month_short(date)).to eq("Feb 15")
        end
      end
    end
  end

  describe "datetime formats" do
    describe ".long_with_time" do
      it "formats in French" do
        I18n.with_locale(:fr) do
          expect(DateFormatHelper.long_with_time(datetime)).to eq("15 février 2024 à 14:30")
        end
      end

      it "formats in English with AM/PM" do
        I18n.with_locale(:en) do
          expect(DateFormatHelper.long_with_time(datetime)).to eq("February 15, 2024 at 02:30 PM")
        end
      end
    end

    describe ".long_with_time_and_timezone" do
      it "formats in French with timezone" do
        I18n.with_locale(:fr) do
          result = DateFormatHelper.long_with_time_and_timezone(datetime)
          expect(result).to match(/\A15 février 2024 à 14:30 \(CE(S)?T\)\z/)
        end
      end

      it "formats in English with timezone" do
        I18n.with_locale(:en) do
          result = DateFormatHelper.long_with_time_and_timezone(datetime)
          expect(result).to match(/\AFebruary 15, 2024 at 02:30 PM \(CE(S)?T\)\z/)
        end
      end
    end

    describe ".short_with_time" do
      it "formats identically in both locales" do
        expect(DateFormatHelper.short_with_time(datetime)).to eq("15/02/2024 14:30")
      end
    end

    describe ".messagerie_date" do
      it "formats in French with Le prefix" do
        I18n.with_locale(:fr) do
          expect(DateFormatHelper.messagerie_date(datetime)).to eq("Le 15/02/2024 14:30")
        end
      end

      it "formats in English without prefix" do
        I18n.with_locale(:en) do
          expect(DateFormatHelper.messagerie_date(datetime)).to eq("15/02/2024 14:30")
        end
      end
    end

    describe ".human" do
      it "formats in French" do
        I18n.with_locale(:fr) do
          expect(DateFormatHelper.human(datetime)).to eq("jeudi 15 février à 14h30")
        end
      end

      it "formats in English" do
        I18n.with_locale(:en) do
          expect(DateFormatHelper.human(datetime)).to eq("Thursday 15 February at 02:30 PM")
        end
      end
    end

    describe ".message_date_with_year" do
      it "formats in French with 1er for first day" do
        I18n.with_locale(:fr) do
          first_of_month = Time.zone.local(2024, 3, 1, 10, 5)
          expect(DateFormatHelper.message_date_with_year(first_of_month)).to eq("le 1er mars 2024 à 10 h 05")
        end
      end

      it "formats in French with regular day" do
        I18n.with_locale(:fr) do
          expect(DateFormatHelper.message_date_with_year(datetime)).to eq("le 15 février 2024 à 14 h 30")
        end
      end

      it "formats in English with ordinal" do
        I18n.with_locale(:en) do
          expect(DateFormatHelper.message_date_with_year(datetime)).to eq("February 15th 2024 at 14:30")
        end
      end
    end

    describe ".veryshort" do
      it "formats in French without year when current year" do
        I18n.with_locale(:fr) do
          now = Time.zone.local(Date.current.year, 3, 5, 9, 15)
          expect(DateFormatHelper.veryshort(now)).to eq("05/03 09:15")
        end
      end

      it "formats in French with year when different year" do
        I18n.with_locale(:fr) do
          expect(DateFormatHelper.veryshort(datetime)).to eq("15/02/2024 14:30")
        end
      end

      it "formats in English without year when current year" do
        I18n.with_locale(:en) do
          now = Time.zone.local(Date.current.year, 3, 5, 9, 15)
          expect(DateFormatHelper.veryshort(now)).to eq("5 Mar 09:15")
        end
      end

      it "formats in English with year when different year" do
        I18n.with_locale(:en) do
          expect(DateFormatHelper.veryshort(datetime)).to eq("15 Feb 2024 14:30")
        end
      end
    end

    describe ".message_date_without_time" do
      it "formats identically in both locales" do
        expect(DateFormatHelper.message_date_without_time(datetime)).to eq("15/02/2024")
      end
    end
  end
end
