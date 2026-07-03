# frozen_string_literal: true

describe Migrations::BatchUpdateDatetimeValuesJob, type: :job do
  let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
  let(:types_de_champ_public) { [{ type: :datetime, mandatory: }] }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:datetime_champ) { dossier.project_champs_public.first }
  let(:mandatory) { true }

  before do
    if value.nil?
      sql = "UPDATE champs SET value = NULL WHERE id = #{datetime_champ.champ_data.id}"
    else
      sql = "UPDATE champs SET value = '#{value}' WHERE id = #{datetime_champ.champ_data.id}"
    end
    ActiveRecord::Base.connection.execute(sql)
    datetime_champ.reload
  end

  context "when the value is a valid ISO8601 date" do
    let!(:value) { Time.zone.parse('10/01/2023 13:30').iso8601 }

    subject { described_class.perform_now([datetime_champ.champ_data.id]) }

    it "keeps the existing value" do
      subject
      expect(datetime_champ.reload.value).to eq(value)
    end
  end

  context "when the value is a date convertible to IS8061" do
    let!(:value) { "2023-01-10" }

    subject { described_class.perform_now([datetime_champ.champ_data.id]) }

    it "updates the value to ISO8601" do
      subject
      expect(datetime_champ.reload.value).to eq(Time.zone.parse(value).iso8601)
    end
  end

  context "when the value is a date not convertible to IS8061" do
    let!(:value) { "blabla" }
    let!(:mandatory) { false }

    subject { described_class.perform_now([datetime_champ.champ_data.id]) }

    it "updates the value to nil" do
      subject
      expect(datetime_champ.reload.value).to be_nil
    end
  end

  context "when the value is a date not convertible to IS8061 and the champ is required" do
    let!(:value) { "blabla" }

    subject { described_class.perform_now([datetime_champ.champ_data.id]) }

    it "keeps the existing value" do
      allow_any_instance_of(Champs::DatetimeChamp).to receive(:required?).and_return(true)

      subject

      expect(datetime_champ.reload.value).to eq("blabla")
    end
  end

  context "when the value is nil" do
    let!(:value) { nil }

    subject { described_class.perform_now([datetime_champ.champ_data.id]) }

    it "keeps the value to nil" do
      subject
      expect(datetime_champ.reload.value).to be_nil
    end
  end
end
