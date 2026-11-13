# frozen_string_literal: true

RSpec.describe TypeDeChamps::ConditionCycleValidator do
  include Logic

  def condition_on(stable_id) = ds_eq(champ_value(stable_id), constant(true))

  def cycle_error = procedure.errors.find { it.type == :condition_cycle }

  context 'when a public champ and an annotation are conditioned on each other' do
    let_it_be(:procedure) do
      create(:procedure,
        public_type_de_champs: [{ type: :yes_no, libelle: 'P', stable_id: 1, condition: condition_on(10) }],
        private_type_de_champs: [{ type: :yes_no, libelle: 'A', stable_id: 10, condition: condition_on(1) }])
    end

    it 'refuses the publication, pointing to a type de champ of the loop' do
      expect(procedure.valid?(:publication)).to be false

      expect(procedure.errors).to be_of_kind(:draft_type_de_champs, :condition_cycle)
      expect(cycle_error.options[:type_de_champ].stable_id).to be_in([1, 10])
      expect(cycle_error.options[:libelles]).to be_in(['P → A → P', 'A → P → A'])
    end

    it 'is reported once from either editor' do
      [:public_type_de_champs_editor, :private_type_de_champs_editor].each do |context|
        procedure.validate(context)

        expect(procedure.errors.count { it.type == :condition_cycle }).to eq(1)
      end
    end

    it 'does not run without a validation context' do
      procedure.validate

      expect(procedure.errors).not_to be_of_kind(:draft_type_de_champs, :condition_cycle)
    end
  end

  context 'when the cycle goes through several champs' do
    let_it_be(:procedure) do
      create(:procedure,
        public_type_de_champs: [
          { type: :yes_no, libelle: 'P1', stable_id: 1, condition: condition_on(11) },
          { type: :yes_no, libelle: 'P2', stable_id: 2, condition: condition_on(12) },
        ],
        private_type_de_champs: [
          { type: :yes_no, libelle: 'A1', stable_id: 11, condition: condition_on(2) },
          { type: :yes_no, libelle: 'A2', stable_id: 12, condition: condition_on(1) },
        ])
    end

    it 'reports the whole loop' do
      procedure.validate(:publication)

      expect(cycle_error.options[:libelles].split(' → ').uniq).to contain_exactly('P1', 'A1', 'P2', 'A2')
    end
  end

  context 'when two champs of a repetition row are conditioned on each other' do
    let_it_be(:procedure) do
      create(:procedure,
        public_type_de_champs: [
          {
            type: :repetition, libelle: 'R', stable_id: 1, children: [
              { type: :yes_no, libelle: 'C1', stable_id: 2, condition: condition_on(3) },
              { type: :yes_no, libelle: 'C2', stable_id: 3, condition: condition_on(2) },
            ],
          },
        ])
    end

    it 'reports the loop, since a child sees its own row' do
      procedure.validate(:publication)

      expect(procedure.errors).to be_of_kind(:draft_type_de_champs, :condition_cycle)
    end
  end

  context 'when an annotation is conditioned on a repetition child' do
    let_it_be(:procedure) do
      create(:procedure,
        public_type_de_champs: [
          { type: :repetition, libelle: 'R', stable_id: 1, children: [{ type: :yes_no, libelle: 'C', stable_id: 2, condition: condition_on(10) }] },
        ],
        private_type_de_champs: [{ type: :yes_no, libelle: 'A', stable_id: 10, condition: condition_on(2) }])
    end

    it 'reports no cycle, since a root champ never sees a repetition child' do
      procedure.validate(:publication)

      expect(procedure.errors).not_to be_of_kind(:draft_type_de_champs, :condition_cycle)
    end
  end

  context 'when two public champs are conditioned on the same annotation' do
    let_it_be(:procedure) do
      create(:procedure,
        public_type_de_champs: [
          { type: :yes_no, libelle: 'P1', stable_id: 1, condition: condition_on(10) },
          { type: :yes_no, libelle: 'P2', stable_id: 2, condition: condition_on(10) },
        ],
        private_type_de_champs: [{ type: :yes_no, libelle: 'A', stable_id: 10 }])
    end

    it 'reports no cycle' do
      procedure.validate(:publication)

      expect(procedure.errors).not_to be_of_kind(:draft_type_de_champs, :condition_cycle)
    end
  end
end
