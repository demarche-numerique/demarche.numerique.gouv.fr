# frozen_string_literal: true

describe Procedure::AddressEligibilityNoticeComponent, type: :component do
  let(:procedure) { build(:procedure) }

  before do
    allow(procedure.active_revision).to receive(:address_eligible_territories).and_return(territories)
  end

  subject { render_inline(described_class.new(procedure:)) }

  def territories_for(departements: [], regions: []) = { departements:, regions: }

  [
    [{ departements: ['50'] }, "La démarche n’est éligible qu’aux adresses situées dans le département 50 – Manche."],
    [{ departements: ['50', '14'] }, "La démarche n’est éligible qu’aux adresses situées dans l’un des départements suivants : 50 – Manche, 14 – Calvados."],
    [{ regions: ['28'] }, "La démarche n’est éligible qu’aux adresses situées dans la région Normandie."],
    [{ regions: ['28', '53'] }, "La démarche n’est éligible qu’aux adresses situées dans l’une des régions suivantes : Normandie, Bretagne."],
    [{ departements: ['50'], regions: ['53'] }, "La démarche n’est éligible qu’aux adresses situées dans le département 50 – Manche ou dans la région Bretagne."],
    [{ departements: ['50'], regions: ['53', '52'] }, "La démarche n’est éligible qu’aux adresses situées dans le département 50 – Manche ou dans l’une des régions suivantes : Bretagne, Pays de la Loire."],
    [{ departements: ['50', '76'], regions: ['53'] }, "La démarche n’est éligible qu’aux adresses situées dans l’un des départements suivants : 50 – Manche, 76 – Seine-Maritime, ou dans la région Bretagne."],
    [{ departements: ['50', '76'], regions: ['53', '52'] }, "La démarche n’est éligible qu’aux adresses situées dans l’un des départements suivants : 50 – Manche, 76 – Seine-Maritime, ou dans l’une des régions suivantes : Bretagne, Pays de la Loire."],
  ].each do |codes, sentence|
    context "with #{codes}" do
      let(:territories) { territories_for(**codes) }

      it { expect(subject).to have_css('p > span', exact_text: sentence) }
    end
  end

  context 'with several labels' do
    let(:territories) { territories_for(departements: ['50', '76']) }

    it 'keeps each label on one line' do
      expect(subject).to have_css('.no-wrap', text: '76 – Seine-Maritime', exact_text: true)
    end
  end

  context 'with an unknown code' do
    let(:territories) { territories_for(departements: ['50', '999']) }

    it { expect(subject.to_html).to be_empty }
  end

  context 'without eligible territories' do
    let(:territories) { nil }

    it { expect(subject.to_html).to be_empty }
  end
end
