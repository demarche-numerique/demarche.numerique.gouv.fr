# frozen_string_literal: true

describe Stat, type: :model do
  describe '.deleted_dossiers_states' do
    subject { Stat.send(:deleted_dossiers_states) }
    it 'find counts for columns' do
      create(:deleted_dossier, dossier_id: create(:dossier).id, state: :accepte, deleted_at: 1.minute.ago, depose_at: 1.minute.ago)
      create(:deleted_dossier, dossier_id: create(:dossier).id, state: :en_construction, deleted_at: 33.days.ago, depose_at: 33.days.ago)
      create(:deleted_dossier, dossier_id: create(:dossier).id, state: :en_construction, deleted_at: 66.days.ago, depose_at: 66.days.ago)
      create(:deleted_dossier, dossier_id: create(:dossier).id, state: :en_construction, deleted_at: 3.months.ago, depose_at: 3.months.ago)
      create(:deleted_dossier, dossier_id: create(:dossier).id, state: :en_instruction, deleted_at: 3.months.ago, depose_at: 3.months.ago)
      create(:deleted_dossier, dossier_id: create(:dossier).id, state: :accepte, deleted_at: 3.months.ago, depose_at: 3.months.ago)
      create(:deleted_dossier, dossier_id: create(:dossier).id, state: :refuse, deleted_at: 3.months.ago, depose_at: 3.months.ago)
      create(:deleted_dossier, dossier_id: create(:dossier).id, state: :sans_suite, deleted_at: 3.months.ago, depose_at: 3.months.ago)

      expect(subject["not_brouillon"]).to eq(8)
      expect(subject["dossiers_depose_avant_30_jours"]).to eq(1)
      expect(subject["dossiers_deposes_entre_60_et_30_jours"]).to eq(1)
    end
  end

  describe '.dossiers_states' do
    # the metric is a global aggregate: run it against an empty dossiers table
    empty_seeds Dossier

    let(:procedure) { create(:procedure, :published) }
    before do
      create_list(:dossier, 2, :en_construction, depose_at: 10.days.ago, procedure:)
      create_list(:dossier, 3, :en_construction, depose_at: 40.days.ago, procedure:)

      create_list(:dossier, 1, :brouillon, procedure:, for_procedure_preview: false)

      create_list(:dossier, 6, :en_instruction, procedure:)

      create_list(:dossier, 5, :accepte, procedure:)
      create_list(:dossier, 1, :refuse, procedure:)
      create_list(:dossier, 1, :sans_suite, procedure:)

      # ignored dossiers
      create(:dossier, :brouillon, procedure: create(:procedure, :draft))
      create(:dossier, :brouillon, for_procedure_preview: true)
    end

    subject(:stats) { Stat.send(:dossiers_states) }

    it 'works' do
      expect(stats["not_brouillon"]).to eq(18)
      expect(stats["dossiers_depose_avant_30_jours"]).to eq(15)
      expect(stats["dossiers_deposes_entre_60_et_30_jours"]).to eq(3)
    end
  end

  describe '.update_stats' do
    it 'merges dossiers_states and deleted_dossiers_states' do
      stats = {
        "not_brouillon" => 1,
        "dossiers_depose_avant_30_jours" => 2,
        "dossiers_deposes_entre_60_et_30_jours" => 3,
      }
      allow(Stat).to receive(:dossiers_states).and_return(stats)
      allow(Stat).to receive(:deleted_dossiers_states).and_return(stats)

      Stat.update_stats
      computed_stats = Stat.first

      expect(computed_stats.dossiers_not_brouillon).to eq(2)
      expect(computed_stats.dossiers_depose_avant_30_jours).to eq(4)
      expect(computed_stats.dossiers_deposes_entre_60_et_30_jours).to eq(6)
    end
  end

  describe '.cumulative_hash' do
    # the metric is a global aggregate: run it against an empty dossiers table
    empty_seeds Dossier

    it 'works count and cumulate counters by month for both dossier and deleted dossiers' do
      2.downto(1).map do |i|
        create(:dossier, state: :en_construction, depose_at: i.months.ago)
        create(:deleted_dossier, dossier_id: i + 100, state: :en_construction, deleted_at: i.month.ago)
      end
      s = Stat.new({
        dossiers_cumulative:
                        Stat.send(:cumulative_month_serie, [
                          [Dossier.state_not_brouillon, :depose_at],
                          [DeletedDossier.where.not(state: :brouillon), :deleted_at],
                        ]),
      })
      s.save!
      s.reload
      # Use `Hash#to_a` to also test the key ordering
      expect(s.dossiers_cumulative.to_a).to eq([
        [formatted_n_months_ago(2), 2],
        [formatted_n_months_ago(1), 4],
      ])
    end
  end

  describe '.last_four_months_hash' do
    it 'works count and cumulate counters by month for both dossier and deleted dossiers' do
      travel_to Time.zone.local(2021, 11, 25) do
        4.downto(1).map do |i|
          create(:dossier, state: :en_construction, depose_at: i.months.ago)
          create(:deleted_dossier, dossier_id: i + 100, state: :en_construction, deleted_at: i.month.ago)
        end
        s = Stat.new({
          dossiers_in_the_last_4_months:
                                   Stat.send(:last_four_months_serie, [
                                     [Dossier.state_not_brouillon, :depose_at],
                                     [DeletedDossier.where.not(state: :brouillon), :deleted_at],
                                   ]),
        })
        s.save!
        s.reload
        # Use `Hash#to_a` to also test the key ordering
        expect(s.dossiers_in_the_last_4_months.to_a).to eq([
          ['2021-07-01', 2],
          ['2021-08-01', 2],
          ['2021-09-01', 2],
          ['2021-10-01', 2],
        ])
      end
    end
  end

  describe '.sum_hashes' do
    it 'sum up hashes keys' do
      expect(Stat.send(:sum_hashes, *[{ a: 1, b: 2, d: 5 }, { a: 2, b: 3, c: 5 }])).to eq({ a: 3, b: 5, c: 5, d: 5 })
    end
  end

  def formatted_n_months_ago(i)
    i.months.ago.beginning_of_month.to_date.to_s
  end
end
