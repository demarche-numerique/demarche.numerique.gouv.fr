# frozen_string_literal: true

describe 'experts/avis/instruction', type: :view do
  before do
    assign(:avis, current_avis)
    assign(:new_avis, Avis.new)
    assign(:dossier, current_avis.dossier)
    allow(view).to receive(:current_expert).and_return(current_avis.expert)
  end

  subject { render }

  context 'with a confidential avis' do
    let(:current_avis) { avis.confidentiel }
    it { is_expected.to have_text("Cet avis est confidentiel et n’est pas affiché aux autres experts consultés") }
  end

  context 'with a not confidential avis' do
    let(:current_avis) { avis.pending }
    it { is_expected.to have_text("Cet avis est partagé avec les autres experts") }
  end

  context 'with a request date' do
    let(:current_avis) { avis.pending }

    before { current_avis.update_column(:created_at, Time.zone.local(2026, 12, 1, 14, 5)) }

    it { is_expected.to have_text('Demande d’avis envoyée le 01/12/2026') }

    it 'dates the request in English' do
      I18n.with_locale(:en) { expect(render).to have_text('Opinion requested on 1 December 2026') }
    end
  end

  context 'when the avis has a question' do
    let(:current_avis) { create(:avis, question_label: "is it useful?", claimant: instructeurs.default, experts_procedure: experts_procedures.default, dossier: dossiers.en_instruction) }

    it do
      is_expected.to have_text(current_avis.question_label)
      is_expected.to have_unchecked_field("oui")
    end
  end

  context 'when the avis has no question' do
    let(:current_avis) { create(:avis, question_label: "", claimant: instructeurs.default, experts_procedure: experts_procedures.default, dossier: dossiers.en_instruction) }
    it { is_expected.not_to have_unchecked_field("oui") }
  end

  describe 'given avis counter on "Voir les avis"' do
    let(:current_avis) { avis.pending }

    context 'when avis visible to the expert have been given' do
      before do
        current_avis.update_columns(answer: "Mon avis")
        create(:avis, dossier: current_avis.dossier, claimant: instructeurs.default, experts_procedure: experts_procedures.second, confidentiel: false, answer: "Avis partagé")
        avis.confidentiel.update_columns(answer: "Avis confidentiel")
      end

      it 'counts them, ignoring the confidential avis of another expert' do
        is_expected.to have_css(".fr-sidemenu__count", text: "(2)")
        is_expected.to have_css(".fr-sr-only", text: "2 avis rendus")
      end
    end
  end
end
