# frozen_string_literal: true

describe AddressEligibilityConcern do
  include Logic

  describe '#address_eligible_territories' do
    let(:address) { { type: :address, stable_id: 100, mandatory: true } }
    let(:public_type_de_champs) { [address] }
    let(:procedure) { create(:procedure, public_type_de_champs:) }
    let(:revision) { procedure.draft_revision }
    let(:address_tdc) { revision.type_de_champs.find { it.stable_id == 100 } }
    let(:ineligibilite_enabled) { true }

    before do
      revision.update!(ineligibilite_enabled:, ineligibilite_message: 'Hors territoire', ineligibilite_rules: rules)
    end

    subject { revision.reload.address_eligible_territories }

    def column(label) = address_tdc.columns(procedure_id: procedure.id).find { it.label.include?("– #{label}") }
    def departement_not(code) = ds_not_eq(champ_column_value(column('Département')), constant(code))
    def region_not(code) = ds_not_eq(champ_column_value(column('Région')), constant(code))

    context 'with a single departement rule from the new editor' do
      let(:rules) { departement_not('50') }

      it { is_expected.to eq(departements: ['50'], regions: []) }
    end

    context 'with a single rule from the old editor' do
      let(:rules) { ds_not_in_departement(champ_value(100), constant('50')) }

      it { is_expected.to eq(departements: ['50'], regions: []) }
    end

    context 'with departement and region rules joined by and, from both editors' do
      let(:rules) do
        ds_and([
          departement_not('50'),
          ds_not_in_departement(champ_value(100), constant('14')),
          region_not('53'),
          ds_not_in_region(champ_value(100), constant('28')),
        ])
      end

      it { is_expected.to eq(departements: ['50', '14'], regions: ['53', '28']) }
    end

    context 'when the ineligibility is disabled' do
      let(:ineligibilite_enabled) { false }
      let(:rules) { departement_not('50') }

      it { is_expected.to be_nil }
    end

    context 'when a rule is "is" (new editor)' do
      let(:rules) { ds_and([departement_not('50'), ds_eq(champ_column_value(column('Département')), constant('14'))]) }

      it { is_expected.to be_nil }
    end

    context 'when a rule is "is in" (old editor)' do
      let(:rules) { ds_in_region(champ_value(100), constant('28')) }

      it { is_expected.to be_nil }
    end

    context 'when the rules are joined by or' do
      let(:rules) { ds_or([departement_not('50'), departement_not('14')]) }

      it { is_expected.to be_nil }
    end

    context 'when a rule targets another address column' do
      let(:rules) { ds_not_eq(champ_column_value(column('Code postal')), constant('50000')) }

      it { is_expected.to be_nil }
    end

    context 'when the form has several address fields' do
      let(:public_type_de_champs) { [address, { type: :address, stable_id: 101 }] }
      let(:rules) { departement_not('50') }

      it { is_expected.to be_nil }
    end

    context 'when the address is optional' do
      let(:address) { { type: :address, stable_id: 100, mandatory: false } }
      let(:rules) { departement_not('50') }

      it { is_expected.to be_nil }
    end

    context 'when the address is conditional' do
      let(:public_type_de_champs) { [{ type: :yes_no, stable_id: 90 }, address.merge(condition: ds_eq(champ_value(90), constant(true)))] }
      let(:rules) { departement_not('50') }

      it { is_expected.to be_nil }
    end

    context 'when the address is in a repetition' do
      let(:public_type_de_champs) { [{ type: :repetition, stable_id: 90, children: [address] }] }
      let(:rules) { ds_not_in_departement(champ_value(100), constant('50')) }

      it { is_expected.to be_nil }
    end
  end
end
