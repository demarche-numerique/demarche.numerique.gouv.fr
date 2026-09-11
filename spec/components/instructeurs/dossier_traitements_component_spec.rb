# frozen_string_literal: true

RSpec.describe Instructeurs::DossierTraitementsComponent, type: :component do
  let(:dossier) { create(:dossier, :en_construction) }
  let(:instructeur_email) { nil }

  subject { render_inline(described_class.new(traitements: dossier.traitements.reload)) }

  # a dossier deposé, puis passé en instruction, puis repassé en construction
  before do
    dossier.traitements.destroy_all
    dossier.traitements.create!(state: Dossier.states.fetch(:en_construction), processed_at: 3.hours.ago)
    dossier.traitements.create!(state: Dossier.states.fetch(:en_instruction), instructeur_email:, processed_at: 2.hours.ago)
    dossier.traitements.create!(state: Dossier.states.fetch(:en_construction), instructeur_email:, processed_at: 1.hour.ago)
  end

  context "when the traitement was made by an instructeur" do
    let(:instructeur_email) { "instructeur@example.org" }

    it "names the instructeur" do
      expect(subject.to_html).to include("lʼinstructeur instructeur@example.org a repassé ce dossier en construction")
    end
  end

  context "when the traitement has no instructeur email" do
    it "renders without raising a missing interpolation error" do
      expect { subject }.not_to raise_error
    end

    it "falls back to a neutral label" do
      expect(subject.to_html).to include("lʼinstructeur non identifié a repassé ce dossier en construction")
    end
  end
end
