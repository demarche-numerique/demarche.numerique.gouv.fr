# frozen_string_literal: true

RSpec.describe Instructeurs::SVASVRDecisionBadgeComponent, type: :component do
  let(:procedure) { create(:procedure, sva_svr: { decision: :sva, period: 10, unit: :days, resume: :continue }) }
  let(:with_label) { false }

  before do
    travel_to DateTime.new(2023, 9, 1)
  end

  context 'with dossier object' do
    subject do
      render_inline(described_class.new(dossier:, procedure:, with_label:))
    end

    let(:title) { subject.at_css("span")["title"] }

    context 'dossier en instruction' do
      let(:dossier) { create(:dossier, :en_instruction, procedure:, sva_svr_decision_on: Date.new(2023, 9, 5)) }
      it do
        expect(subject).to have_text("dans 4 jours")
        expect(title).to have_text("sera automatiquement traité le 05 septembre 2023")
      end

      context 'with label' do
        let(:with_label) { true }
        it { expect(subject.text.delete("\n")).to have_text("SVA : dans 4 jours") }
      end
    end

    context 'without sva date' do
      let(:dossier) { create(:dossier, :en_instruction, procedure:) }

      context 'dossier depose before configuration' do
        it do
          expect(subject).to have_text("Déposé avant SVA")
          expect(title).to have_text("avant la configuration SVA")
        end
      end

      context 'dossier previously terminated' do
        before {
          create(:traitement, :accepte, dossier:)
        }

        it do
          expect(subject).to have_text("Instruction manuelle")
          expect(title).to have_text("repassé en instruction")
        end
      end
    end

    context 'pending corrections' do
      let(:dossier) { create(:dossier, :en_construction, procedure:, depose_at: Time.current, sva_svr_decision_on: Date.new(2023, 9, 5)) }

      before do
        create(:dossier_correction, dossier:)
      end

      it { expect(subject).to have_text("4 j. après correction") }
    end
  end

  describe 'once the rule is disabled' do
    before_all { seed "cases/sva" }

    let(:procedure) { procedures.sva }

    before { procedure.update_column(:sva_svr, procedure.sva_svr.merge('disabled_at' => Time.current.iso8601)) }

    subject { render_inline(described_class.new(dossier:, procedure:)) }

    context 'on a dossier the rule already dated' do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:, sva_svr_decision_on: Date.new(2023, 9, 5)) }

      it { expect(subject).to have_text("dans 4 jours") }
    end
  end
end
