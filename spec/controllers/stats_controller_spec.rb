# frozen_string_literal: true

describe StatsController, type: :controller do
  before { travel_to(Date.parse("2021/12/15")) }

  describe "#last_four_months_hash" do
    context "while a regular user is logged in" do
      before do
        create(:procedure, created_at: 6.months.ago, updated_at: 6.months.ago)
        create(:procedure, created_at: 2.months.ago, updated_at: 62.days.ago)
        create(:procedure, created_at: 2.months.ago, updated_at: 62.days.ago)
        create(:procedure, created_at: 2.months.ago, updated_at: 31.days.ago)
        create(:procedure, created_at: 2.months.ago, updated_at: Time.zone.now)
        @controller = StatsController.new

        allow(@controller).to receive(:super_admin_signed_in?).and_return(false)
      end

      let(:association) { Procedure.all }

      subject { @controller.send(:last_four_months_serie, association, :updated_at) }

      it do
        expect(subject).to eq({
          4.months.ago => 0,
          3.months.ago => 0,
          62.days.ago => 2,
          31.days.ago => 1,
        }.transform_keys { |date| DateFormatHelper.month_year(date) })
      end
    end

    context "while a super admin is logged in" do
      before do
        create(:procedure, updated_at: 6.months.ago)
        create(:procedure, updated_at: 45.days.ago)
        create(:procedure, updated_at: 1.day.ago)
        create(:procedure, updated_at: 1.day.ago)

        @controller = StatsController.new

        allow(@controller).to receive(:super_admin_signed_in?).and_return(true)
      end

      let (:association) { Procedure.all }

      subject { @controller.send(:last_four_months_serie, association, :updated_at) }

      it do
        expect(subject).to eq({
          3.months.ago => 0,
          45.days.ago => 1,
          1.month.ago => 0,
          1.day.ago => 2,
        }.transform_keys { |date| DateFormatHelper.month_year(date) })
      end
    end
  end

  describe '#cumulative_hash' do
    before do
      travel_to(Time.zone.local(2016, 10, 2))
      create(:procedure, created_at: 55.days.ago, updated_at: 43.days.ago)
      create(:procedure, created_at: 45.days.ago, updated_at: 40.days.ago)
      create(:procedure, created_at: 45.days.ago, updated_at: 20.days.ago)
      create(:procedure, created_at: 15.days.ago, updated_at: 20.days.ago)
      create(:procedure, created_at: 15.days.ago, updated_at: 1.hour.ago)
    end

    let (:association) { Procedure.all }

    context "while a super admin is logged in" do
      before { allow(@controller).to receive(:super_admin_signed_in?).and_return(true) }

      subject { @controller.send(:cumulative_month_serie, association, :updated_at) }

      it do
        expect(subject).to eq({
          Date.new(2016, 8, 1) => 2,
          Date.new(2016, 9, 1) => 4,
          Date.new(2016, 10, 1) => 5,
        })
      end
    end

    context "while a super admin is not logged in" do
      before { allow(@controller).to receive(:super_admin_signed_in?).and_return(false) }

      subject { @controller.send(:cumulative_month_serie, association, :updated_at) }

      it do
        expect(subject).to eq({
          Date.new(2016, 8, 1) => 2,
          Date.new(2016, 9, 1) => 4,
        })
      end
    end
  end
end
