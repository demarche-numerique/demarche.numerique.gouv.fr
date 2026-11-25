# frozen_string_literal: true

RSpec.describe ProcedureHelper, type: :helper do
  describe '#procedure_auto_archive_datetime' do
    let(:auto_archive_date) { Time.zone.local(2020, 8, 2, 12, 00) }
    let(:procedure) { build(:procedure, auto_archive_on: auto_archive_date) }

    subject { procedure_auto_archive_datetime(procedure) }

    it "displays the day before the auto archive date (to account for the '23h59' ending time)" do
      expect(subject).to eq("1 août 2020 à 23 h 59 (heure de Paris)")
    end

    it "is fully translated in English" do
      I18n.with_locale(:en) do
        expect(subject).to eq("1 August 2020 at 11:59 PM (Paris time)")
      end
    end
  end

  describe '#procedure_auto_archive_time' do
    it 'gives the ending time in both languages' do
      expect(procedure_auto_archive_time).to eq("à 23 h 59 (heure de Paris)")
      I18n.with_locale(:en) { expect(procedure_auto_archive_time).to eq("at 11:59 PM (Paris time)") }
    end
  end

  describe '#estimated_fill_duration_minutes' do
    subject { estimated_fill_duration_minutes(procedure.reload) }

    context 'with champs' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :yes_no }, { type: :piece_justificative }]) }

      it 'rounds up the duration to the minute' do
        expect(subject).to eq(3)
      end
    end

    context 'without champs' do
      let(:procedure) { create(:procedure) }

      it 'never displays ’zero minutes’' do
        expect(subject).to eq(1)
      end
    end
  end

  describe '#admin_procedures_back_label' do
    subject { helper.admin_procedures_back_label(procedure) }

    context 'with a published procedure' do
      let(:procedure) { build(:procedure, :published) }
      it { is_expected.to eq('Démarches publiées') }
    end

    context 'with a draft procedure' do
      let(:procedure) { build(:procedure) }
      it { is_expected.to eq('Démarches en test') }
    end

    context 'with a closed procedure' do
      let(:procedure) { build(:procedure, :closed) }
      it { is_expected.to eq('Démarches terminées') }
    end

    context 'with a depubliee procedure' do
      let(:procedure) { build(:procedure, :unpublished) }
      it { is_expected.to eq('Démarches terminées') }
    end

    context 'with a discarded procedure' do
      let(:procedure) { build(:procedure, :discarded) }
      it { is_expected.to eq('Démarches supprimées') }
    end
  end
end
