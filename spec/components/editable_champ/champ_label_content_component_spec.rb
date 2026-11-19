# frozen_string_literal: true

RSpec.describe EditableChamp::ChampLabelContentComponent, type: :component do
  describe "rendering the modification date" do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text, libelle: "Texte" }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:champ) { dossier.public_root_champs.first }
    let(:value_updated_at) { 3.days.ago.change(usec: 0) }
    let(:seen_at) { 1.day.ago }
    let(:component) { described_class.new(form: nil, champ:, seen_at:) }

    subject { render_inline(component) }

    before { champ.update_columns(updated_at: 1.hour.ago, value_updated_at:) }

    it "dates the last user change, not the Rails timestamp, and does not highlight it once seen" do
      expect(subject).to have_css(".updated-at", text: "modifié le #{I18n.l(value_updated_at)}")
      expect(subject).not_to have_css(".updated-at.highlighted")
    end

    context "when the champ was rebased after the last user change, then bumped by machinery" do
      let(:seen_at) { nil }

      before do
        champ.update_columns(rebased_at: 2.days.ago)
        allow(component).to receive(:current_user).and_return(dossier.user)
      end

      it "still asks the usager to check the content" do
        expect(subject).to have_text("champ actualisé par l’administration")
      end
    end
  end
end
