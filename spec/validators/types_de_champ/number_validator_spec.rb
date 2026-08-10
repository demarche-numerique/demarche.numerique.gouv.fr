# frozen_string_literal: true

RSpec.describe TypesDeChamp::NumberValidator do
  shared_examples "number range validation" do |scope:, type:|
    let(:attribute) do
      scope == :types_de_champ_public ? :draft_public_types_de_champ : :draft_private_types_de_champ
    end

    let(:validation_context) do
      scope == :types_de_champ_public ? :public_types_de_champ_editor : :private_types_de_champ_editor
    end

    let(:procedure) do
      build(
        :procedure,
        scope => [
          {
            type: type,
            range_number: '1',
            min_number: min,
            max_number: max,
            positive_number: positive,
          },
        ]
      )
    end

    subject { procedure.validate(validation_context) }

    context "when min and max are missing" do
      let(:min) { nil }
      let(:max) { nil }
      let(:positive) { nil }

      it "adds a missing_range_rules error" do
        subject

        expect(procedure.errors.details[attribute])
          .to include(hash_including(error: :missing_range_rules))
      end
    end

    context "when min is greater than max" do
      let(:min) { 5 }
      let(:max) { 2 }
      let(:positive) { nil }

      it "adds an invalid_range_rules error" do
        subject

        expect(procedure.errors.details[attribute])
          .to include(hash_including(error: :invalid_range_rules))
      end
    end

    context "when number is positive and max is negative" do
      let(:min) { 0 }
      let(:max) { -1 }
      let(:positive) { '1' }

      it "adds an invalid_positive_range_rules error" do
        subject

        expect(procedure.errors.details[attribute])
          .to include(hash_including(error: :invalid_positive_range_rules))
      end
    end

    context "when range is valid with min and max" do
      let(:min) { 0 }
      let(:max) { 10 }
      let(:positive) { '1' }

      it "does not add any errors" do
        subject

        expect(procedure.errors.details[attribute]).to be_empty
      end
    end

    context "when range is valid with empty max" do
      let(:min) { 0 }
      let(:max) { '' }
      let(:positive) { '1' }

      it "does not add any errors" do
        subject

        expect(procedure.errors.details[attribute]).to be_empty
      end
    end
  end

  describe "public types_de_champ" do
    include_examples "number range validation",
      scope: :types_de_champ_public,
      type: :decimal_number

    include_examples "number range validation",
      scope: :types_de_champ_public,
      type: :integer_number
  end

  describe "private types_de_champ" do
    include_examples "number range validation",
      scope: :types_de_champ_private,
      type: :decimal_number

    include_examples "number range validation",
      scope: :types_de_champ_private,
      type: :integer_number
  end
end
