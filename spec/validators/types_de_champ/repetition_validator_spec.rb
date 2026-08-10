# frozen_string_literal: true

RSpec.describe TypesDeChamp::RepetitionValidator do
  shared_examples "repetition limits validation" do |scope:|
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
            type: :repetition,
            children: [{ type: :text }],
            limit_repetitions: '1',
            min_repetitions: min,
            max_repetitions: max,
            mandatory: mandatory,
          },
        ]
      )
    end

    subject { procedure.validate(validation_context) }

    context "when block is not mandatory" do
      let(:mandatory) { false }

      context "when min and max are both blank" do
        let(:min) { nil }
        let(:max) { nil }

        it "adds a missing_repetition_min_or_max error" do
          subject
          expect(procedure.errors.details[attribute])
            .to include(hash_including(error: :missing_repetition_min_or_max))
        end
      end

      context "when min is greater than max" do
        let(:min) { 5 }
        let(:max) { 2 }

        it "adds an invalid_repetition_range error" do
          subject
          expect(procedure.errors.details[attribute])
            .to include(hash_including(error: :invalid_repetition_range))
        end
      end

      context "when min equals max" do
        let(:min) { 3 }
        let(:max) { 3 }

        it "adds an invalid_not_mandatory_repetition_min error" do
          subject
          expect(procedure.errors.details[attribute])
            .to include(hash_including(error: :invalid_not_mandatory_repetition_min))
        end
      end

      context "when min is 0" do
        let(:min) { 0 }
        let(:max) { 5 }

        it "does not add any errors" do
          subject
          expect(procedure.errors.details[attribute]).to be_empty
        end
      end

      context "when max is 0" do
        let(:min) { 0 }
        let(:max) { 0 }

        it "adds an invalid_repetition_max error" do
          subject
          expect(procedure.errors.details[attribute])
            .to include(hash_including(error: :invalid_repetition_max))
        end
      end

      context "when min is negative" do
        let(:min) { -1 }
        let(:max) { 5 }

        it "adds an invalid_not_mandatory_repetition_min error" do
          subject
          expect(procedure.errors.details[attribute])
            .to include(hash_including(error: :invalid_not_mandatory_repetition_min))
        end
      end

      context "when max is negative" do
        let(:min) { nil }
        let(:max) { -1 }

        it "adds an invalid_repetition_max error" do
          subject
          expect(procedure.errors.details[attribute])
            .to include(hash_including(error: :invalid_repetition_max))
        end
      end
    end

    context "when block is mandatory" do
      let(:mandatory) { true }

      context "when min is 0" do
        let(:min) { 0 }
        let(:max) { 5 }

        it "adds an invalid_mandatory_repetition_min error" do
          subject
          expect(procedure.errors.details[attribute])
            .to include(hash_including(error: :invalid_mandatory_repetition_min))
        end
      end

      context "when max is 0" do
        let(:min) { 1 }
        let(:max) { 0 }

        it "adds an invalid_repetition_max error" do
          subject
          expect(procedure.errors.details[attribute])
            .to include(hash_including(error: :invalid_repetition_max))
        end
      end

      context "when min is 1 and max is 5" do
        let(:min) { 1 }
        let(:max) { 5 }

        it "does not add any errors" do
          subject
          expect(procedure.errors.details[attribute]).to be_empty
        end
      end

      context "when min and max are both 1" do
        let(:min) { 1 }
        let(:max) { 1 }

        it "does not add any errors" do
          subject
          expect(procedure.errors.details[attribute]).to be_empty
        end
      end
    end
  end

  describe "public types_de_champ" do
    include_examples "repetition limits validation", scope: :types_de_champ_public
  end

  describe "private types_de_champ" do
    include_examples "repetition limits validation", scope: :types_de_champ_private
  end
end
