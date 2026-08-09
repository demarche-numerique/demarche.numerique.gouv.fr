# frozen_string_literal: true

RSpec.describe TypesDeChamp::DateValidator do
  shared_examples "date range validation" do |scope:, type:|
    let(:attribute) do
      scope == :types_de_champ_public ? :draft_types_de_champ_public : :draft_types_de_champ_private
    end

    let(:validation_context) do
      scope == :types_de_champ_public ? :types_de_champ_public_editor : :types_de_champ_private_editor
    end

    let(:procedure) do
      build(
        :procedure,
        scope => [
          {
            type: type,
            range_date: '1',
            start_date: start_date,
            end_date: end_date,
          },
        ]
      )
    end

    subject { procedure.validate(validation_context) }

    context "when start_date and end_date are missing" do
      let(:start_date) { nil }
      let(:end_date) { nil }

      it "adds a missing_range_date_rules error" do
        subject
        expect(procedure.errors.details[attribute])
          .to include(hash_including(error: :missing_range_date_rules))
      end
    end

    context "when start_date is after end_date" do
      let(:start_date) { "2026-02-01" }
      let(:end_date) { "2026-01-01" }

      it "adds an invalid_range_date_rules error" do
        subject
        expect(procedure.errors.details[attribute])
          .to include(hash_including(error: :invalid_range_date_rules))
      end
    end

    context "when range is valid with start_date and end_date" do
      let(:start_date) { "2026-01-01" }
      let(:end_date) { "2026-02-01" }

      it "does not add any errors" do
        subject
        expect(procedure.errors.details[attribute]).to be_empty
      end
    end

    context "when range is valid with empty end_date" do
      let(:start_date) { "2026-01-01" }
      let(:end_date) { nil }

      it "does not add any errors" do
        subject
        expect(procedure.errors.details[attribute]).to be_empty
      end
    end

    context "when range is valid with empty start_date" do
      let(:start_date) { nil }
      let(:end_date) { "2026-02-01" }

      it "does not add any errors" do
        subject
        expect(procedure.errors.details[attribute]).to be_empty
      end
    end
  end

  describe "public types_de_champ" do
    include_examples "date range validation", scope: :types_de_champ_public, type: :date
    include_examples "date range validation", scope: :types_de_champ_public, type: :datetime
  end

  describe "private types_de_champ" do
    include_examples "date range validation", scope: :types_de_champ_private, type: :date
    include_examples "date range validation", scope: :types_de_champ_private, type: :datetime
  end

  describe "prefill_with_france_connect_information uniqueness" do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :date }, { type: :date }, { type: :text }]) }
    let(:tdcs) { procedure.active_revision.root_types_de_champ_public }

    subject { procedure.validate(:types_de_champ_public_editor) }

    context "when no date field has the option enabled" do
      it "does not add errors" do
        expect { subject }.not_to change { procedure.errors.count }
      end
    end

    context "when a single date field has the option enabled" do
      before { tdcs.first.record.update!(options: { 'birthdate' => '1', 'prefill_with_france_connect_information' => '1' }) }

      it "does not add errors" do
        expect { subject }.not_to change { procedure.errors.count }
      end
    end

    context "when two date fields have the option enabled" do
      before do
        tdcs[0].record.update!(options: { 'birthdate' => '1', 'prefill_with_france_connect_information' => '1' })
        tdcs[1].record.update!(options: { 'birthdate' => '1', 'prefill_with_france_connect_information' => '1' })
      end

      it "adds an error for each conflicting field" do
        subject
        conflicting_errors = procedure.errors.where(:draft_types_de_champ_public, :prefill_with_france_connect_information_taken)
        expect(conflicting_errors.size).to eq(2)
        expect(conflicting_errors.map { it.options[:type_de_champ] }).to match_array([tdcs[0], tdcs[1]])
      end
    end
  end
end
