# frozen_string_literal: true

describe ProcedureStatsConcern do
  describe '#stats_dossiers_funnel' do
    let(:procedure) { create(:procedure) }

    subject(:stats_dossiers_funnel) { procedure.stats_dossiers_funnel }

    before do
      create_list(:dossier, 2, :brouillon, procedure: procedure)
      create(:dossier, :en_instruction, procedure: procedure)
      create(:dossier, procedure: procedure, for_procedure_preview: true)
      create(:dossier, :accepte, procedure: procedure, hidden_by_administration_at: Time.zone.now)
    end

    it "returns the funnel stats" do
      expect(stats_dossiers_funnel).to match(
        [
          ['Tous (dont brouillon)', procedure.dossiers.visible_by_user_or_administration.count],
          ['Déposés', procedure.dossiers.visible_by_administration.count],
          ['Instruction débutée', procedure.dossiers.visible_by_administration.state_instruction_commencee.count],
          ['Traités', procedure.dossiers.visible_by_administration.state_termine.count],
        ]
      )
    end
  end

  describe '#usual_traitement_time_for_recent_dossiers' do
    let(:procedure) { create(:procedure) }

    before do
      travel_to(Time.utc(2019, 6, 1, 12, 0))

      delays.each do |delay|
        create_dossier(depose_at: 1.week.ago - delay, en_instruction_at: 1.week.ago - delay + 12.hours, processed_at: 1.week.ago)
      end
    end

    context 'when there are several processed dossiers' do
      let(:delays) { [1.day, 2.days, 2.days, 2.days, 2.days, 3.days, 3.days, 3.days, 3.days, 12.days] }

      it 'returns a time representative of the dossier instruction delay' do
        expect(procedure.usual_traitement_time_for_recent_dossiers(30)[0]).to be_between(1.day, 2.days)
        expect(procedure.usual_traitement_time_for_recent_dossiers(30)[1]).to be_between(2.days, 3.days)
        expect(procedure.usual_traitement_time_for_recent_dossiers(30)[2]).to be_between(11.days, 12.days)
      end
    end

    context 'when there are very old dossiers' do
      let(:delays) { [1.day, 2.days, 3.days, 3.days, 4.days] }
      let!(:old_dossier) { create_dossier(depose_at: 3.months.ago, en_instruction_at: 2.months.ago, processed_at: 2.months.ago) }

      it 'ignores dossiers older than 1 month' do
        expect(procedure.usual_traitement_time_for_recent_dossiers(30)[0]).to be_between(1.day, 2.days)
        expect(procedure.usual_traitement_time_for_recent_dossiers(30)[1]).to be_between(2.days, 3.days)
        expect(procedure.usual_traitement_time_for_recent_dossiers(30)[2]).to be_between(3.days, 4.days)
      end
    end

    context 'when there is a dossier with bad data' do
      let(:delays) { [1.day, 2.days, 3.days, 3.days, 4.days] }
      let!(:bad_dossier) { create_dossier(depose_at: nil, en_instruction_at: nil, processed_at: 10.days.ago) }

      it 'ignores bad dossiers' do
        expect(procedure.usual_traitement_time_for_recent_dossiers(30)[0]).to be_between(21.hours, 36.hours.days)
        expect(procedure.usual_traitement_time_for_recent_dossiers(30)[1]).to be_between(2.days, 3.days)
        expect(procedure.usual_traitement_time_for_recent_dossiers(30)[2]).to be_between(3.days, 4.days)
      end
    end

    context 'when there is only one processed dossier' do
      let(:delays) { [1.day] }
      it { expect(procedure.usual_traitement_time_for_recent_dossiers(30)).to be_nil }
    end

    context 'where there is no processed dossier' do
      let(:delays) { [] }
      it { expect(procedure.usual_traitement_time_for_recent_dossiers(30)).to eq nil }
    end

    context 'with real data' do
      include ActionView::Helpers::DateHelper
      let(:delays) { [] }
      before do
        csv = CSV.read(Rails.root.join('spec/fixtures/files/data/treatment-expected-3months.csv'))
        traitement_times = csv[1..] # strip header
          .flatten
          .map { { processed_at: _1.to_f, depose_at: 0 } }
        allow(procedure).to receive(:traitement_times).and_return(traitement_times)
      end

      it 'works' do
        expect(procedure.usual_traitement_time_for_recent_dossiers(30).map { distance_of_time_in_words(_1) }).to eq(["3 mois", "6 mois", "environ un an"])
      end
    end
  end

  describe '.usual_traitement_time_by_month_in_days' do
    let(:procedure) { create(:procedure) }

    def create_dossiers(delays_by_month)
      delays_by_month.each_with_index do |delays, index|
        delays.each do |delay|
          processed_at = (index.months + 1.week).ago
          create_dossier(depose_at: processed_at - delay, en_instruction_at: processed_at - delay + 12.hours, processed_at: processed_at)
        end
      end
    end

    before do
      travel_to(Time.utc(2019, 6, 25, 12, 0))

      create_dossiers(delays_by_month)
    end

    context 'when there are several processed dossiers' do
      let(:delays_by_month) {
  [
    [90.days, 90.days],
    [1.day, 2.days, 2.days, 2.days, 2.days, 3.days, 3.days, 3.days, 3.days, 12.days],
    [30.days, 60.days, 60.days, 60.days],
  ]
}

      it 'computes a time representative of the dossier instruction delay for each month except current month' do
        expect(procedure.usual_traitement_time_by_month_in_days['avril 2019']).to eq 54
        expect(procedure.usual_traitement_time_by_month_in_days['mai 2019']).to eq 3
        expect(procedure.usual_traitement_time_by_month_in_days['juin 2019']).to eq nil
      end
    end

    context 'when a month has a winsorized mean traitement time of 0 seconds' do
      let(:delays_by_month) { [[], [0.seconds, 0.seconds]] }

      it 'returns nil for that month instead of raising NoMethodError' do
        expect { procedure.usual_traitement_time_by_month_in_days }.not_to raise_error
        expect(procedure.usual_traitement_time_by_month_in_days['mai 2019']).to be_nil
      end
    end
  end

  private

  def create_dossier(depose_at:, en_instruction_at:, processed_at:)
    dossier = create(:dossier, :accepte, procedure: procedure, depose_at:, en_instruction_at:, processed_at:)
  end
end
