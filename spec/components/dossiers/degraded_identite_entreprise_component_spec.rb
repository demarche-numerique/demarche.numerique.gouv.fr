# frozen_string_literal: true

RSpec.describe Dossiers::DegradedIdentiteEntrepriseComponent, type: :component do
  subject { render_inline(described_class.new(siret: '30613890001294', profile:, **options)).text }

  let(:profile) { 'instructeur' }
  let(:options) { {} }

  it 'tells the instructeur the INSEE is down and the decision has to wait' do
    expect(subject).to include('306 138 900 01294')
    expect(subject).to include('LʼINSEE est indisponible')
    expect(subject).to include('Il nʼest pas possible dʼaccepter ou de refuser')
  end

  context 'when the SIRET was not found' do
    let(:options) { { error_code: 404 } }

    it 'says so, without blocking the decision' do
      expect(subject).to include('Ce SIRET nʼa pas été trouvé dans lʼannuaire de lʼINSEE.')
      expect(subject).not_to include('Il nʼest pas possible dʼaccepter ou de refuser')
    end
  end

  context 'when the SIRET is not diffusible' do
    let(:options) { { error_code: 451 } }

    it 'says so, without blocking the decision' do
      expect(subject).to include('Les informations de cet établissement ne sont pas diffusables (entité non diffusible).')
      expect(subject).not_to include('Il nʼest pas possible dʼaccepter ou de refuser')
    end
  end
end
