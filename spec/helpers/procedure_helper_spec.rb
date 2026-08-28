# frozen_string_literal: true

RSpec.describe ProcedureHelper, type: :helper do
  describe '#procedure_auto_archive_datetime' do
    let(:auto_archive_date) { Time.zone.local(2020, 8, 2, 12, 00) }
    let(:procedure) { build(:procedure, auto_archive_on: auto_archive_date) }

    subject { procedure_auto_archive_datetime(procedure) }

    it "displays the day before the auto archive date (to account for the '23h59' ending time)" do
      expect(subject).to have_text("1 août 2020 à 23 h 59 (heure de Paris)")
    end
  end

  describe '#estimated_fill_minutes_text' do
    include Logic

    subject { estimated_fill_minutes_text(procedure.reload.active_revision) }

    context 'with champs' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :yes_no }, { type: :piece_justificative }]) }

      it 'rounds up the duration to the minute' do
        expect(subject).to eq('3')
      end
    end

    context 'without champs' do
      let(:procedure) { create(:procedure) }

      it 'never displays ’zero minutes’' do
        expect(subject).to eq('1')
      end
    end

    context 'with conditions' do
      let(:procedure) do
        create(:procedure, public_type_de_champs: [
          { type: :yes_no, mandatory: true, description: nil, stable_id: 1 },
          { type: :piece_justificative, mandatory: true, description: nil, condition: ds_eq(champ_value(1), constant(true)) },
        ])
      end

      it 'displays a range' do
        expect(subject).to eq('1 à 3')
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
