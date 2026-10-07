# frozen_string_literal: true

RSpec.describe ConditionCycleValidator do
  include Logic

  let(:revision) { procedure.draft_revision }

  def condition_on(stable_id) = ds_eq(champ_value(stable_id), constant(true))

  context 'when a public champ and an annotation are conditioned on each other' do
    let_it_be(:procedure) do
      create(:procedure,
        public_type_de_champs: [{ type: :yes_no, libelle: 'P', stable_id: 1, condition: condition_on(10) }],
        private_type_de_champs: [{ type: :yes_no, libelle: 'A', stable_id: 10, condition: condition_on(1) }])
    end

    it 'reports the closed loop on base, pointing to a type de champ of the loop' do
      revision.validate(:publication)

      expect(revision.errors).to be_of_kind(:base, :condition_cycle)
      error = revision.errors.find { it.type == :condition_cycle }
      expect(error.options[:type_de_champ].stable_id).to be_in([1, 10])
      expect(error.options[:libelles]).to be_in(['P → A → P', 'A → P → A'])
    end

    it 'refuses the publication and imports the error on the procedure' do
      expect(procedure.valid?(:publication)).to be false
      expect(procedure.errors).to be_of_kind(:base, :condition_cycle)
    end

    it 'does not run without a validation context' do
      revision.validate

      expect(revision.errors).not_to be_of_kind(:base, :condition_cycle)
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
      revision.validate(:publication)

      error = revision.errors.find { it.type == :condition_cycle }
      expect(error.options[:libelles].split(' → ').uniq).to contain_exactly('P1', 'A1', 'P2', 'A2')
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
      revision.validate(:publication)

      expect(revision.errors).not_to be_of_kind(:base, :condition_cycle)
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
      revision.validate(:publication)

      expect(revision.errors).not_to be_of_kind(:base, :condition_cycle)
    end
  end
end
