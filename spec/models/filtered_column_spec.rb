# frozen_string_literal: true

describe FilteredColumn do
  let(:column) { Column.new(procedure_id: 1, table: 'table', column: 'column', label: 'label') }

  describe '#check_filters_max_length' do
    let(:filtered_column) { described_class.new(column:, filter:) }

    before { filtered_column.valid? }

    context 'when the filter is too long' do
      let(:filter) { 'a' * (FilteredColumn::FILTERS_VALUE_MAX_LENGTH + 1) }

      it 'adds an error' do
        expect(filtered_column.errors.map(&:message)).to include(/Le filtre « label » est trop long/)
      end
    end

    context 'when then filter is not too long' do
      let(:filter) { 'a' * FilteredColumn::FILTERS_VALUE_MAX_LENGTH }

      it 'does not add an error' do
        expect(filtered_column.errors).to be_empty
      end
    end
  end

  describe '#check_filters_max_integer' do
    context 'when the target column is an id column' do
      let(:column) { Column.new(procedure_id: 1, table: 'table', column: 'id', label: 'label') }
      let(:filtered_column) { described_class.new(column:, filter:) }

      before { filtered_column.valid? }

      context 'when the filter is too high' do
        let(:filter) { { operator: 'match', value: [(FilteredColumn::PG_INTEGER_MAX_VALUE + 1).to_s] } }

        it 'adds an error' do
          expect(filtered_column.errors.map(&:message)).to include(/Le filtre « label » n’est pas un numéro de dossier possible/)
        end
      end

      context 'when the filter is not too high' do
        let(:filter) { { operator: 'match', value: [FilteredColumn::PG_INTEGER_MAX_VALUE.to_s] } }

        it 'does not add an error' do
          expect(filtered_column.errors).to be_empty
        end
      end
    end
  end

  describe '#check_filter_is_not_blank' do
    let(:filtered_column) { described_class.new(column:, filter:) }

    before { filtered_column.valid? }

    context 'when the filter is blank' do
      let(:filter) { '' }

      it 'adds an error' do
        expect(filtered_column.errors.map(&:message)).to include(/Le filtre « label » ne peut pas être vide/)
      end
    end

    context 'when the filter is not blank' do
      let(:filter) { 'a' }

      it 'does not add an error' do
        expect(filtered_column.errors).to be_empty
      end
    end
  end
end
