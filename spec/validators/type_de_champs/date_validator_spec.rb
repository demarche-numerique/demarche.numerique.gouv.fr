# frozen_string_literal: true

RSpec.describe TypeDeChamps::DateValidator do
  shared_examples "date range validation" do |scope:, type:|
    let(:attribute) do
      scope == :public_type_de_champs ? :public_draft_type_de_champs : :private_draft_type_de_champs
    end

    let(:validation_context) do
      scope == :public_type_de_champs ? :public_type_de_champs_editor : :private_type_de_champs_editor
    end

    let(:procedure) do
      create(
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

  describe "public type_de_champs" do
    include_examples "date range validation", scope: :public_type_de_champs, type: :date
    include_examples "date range validation", scope: :public_type_de_champs, type: :datetime
  end

  describe "private type_de_champs" do
    include_examples "date range validation", scope: :private_type_de_champs, type: :date
    include_examples "date range validation", scope: :private_type_de_champs, type: :datetime
  end

  describe "prefill_with_france_connect_information uniqueness" do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :date }, { type: :date }, { type: :text }]) }
    let(:tdcs) { procedure.active_revision.public_root_type_de_champs }

    subject { procedure.validate(:public_type_de_champs_editor) }

    context "when no date field has the option enabled" do
      it "does not add errors" do
        expect { subject }.not_to change { procedure.errors.count }
      end
    end

    context "when a single date field has the option enabled" do
      before { tdcs.first.update!(options: { 'birthdate' => '1', 'prefill_with_france_connect_information' => '1' }) }

      it "does not add errors" do
        expect { subject }.not_to change { procedure.errors.count }
      end
    end

    context "when two date fields have the option enabled" do
      before do
        tdcs[0].update!(options: { 'birthdate' => '1', 'prefill_with_france_connect_information' => '1' })
        tdcs[1].update!(options: { 'birthdate' => '1', 'prefill_with_france_connect_information' => '1' })
      end

      it "adds an error for each conflicting field" do
        subject
        conflicting_errors = procedure.errors.where(:public_draft_type_de_champs, :prefill_with_france_connect_information_taken)
        expect(conflicting_errors.size).to eq(2)
        expect(conflicting_errors.map { it.options[:type_de_champ] }).to match_array([tdcs[0], tdcs[1]])
      end
    end
  end
end
