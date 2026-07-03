# frozen_string_literal: true

RSpec.describe Dossiers::RNFComponent, type: :component do
  let(:fetch_external_data_exceptions) { [] }

  let(:external_id) { '075-FDD-00003-01' }

  let(:champ) do
    build_projected_champ(build(:type_de_champ_rnf), external_state:, external_id:, data: rnf_data, fetch_external_data_exceptions:)
      .tap { |c| allow(c).to receive(:to_s).and_return('075-FDD-00003-01') }
  end

  subject { render_inline(described_class.new(champ:)) }

  before do
    allow(Dossiers::ExternalChampComponent).to receive(:new).and_call_original
    subject
  end

  context 'when the data is fetched?' do
    let(:external_state) { 'fetched' }
    let(:rnf_data) do
      {
        'title' => 'Fondation SFR',
        'email' => 'contact@fondation-sfr.org',
      }
    end

    it 'renders ExternalChampComponent with correct arguments' do
      # rubocop:disable Lint/UnusedBlockArgument
      expect(Dossiers::ExternalChampComponent).to have_received(:new) do |data:, details:, source:|
        expect(data).to include(['Nom de la fondation', 'Fondation SFR'])
        expect(data).to include(['Adresse électronique', 'contact@fondation-sfr.org'])
        expect(source.to_s).to include('RNF')
      end
      # rubocop:enable Lint/UnusedBlockArgument
    end
  end

  context 'when the champ is waiting for a job' do
    let(:external_state) { 'waiting_for_job' }
    let(:rnf_data) { nil }

    it 'displays a pending message with the identifier' do
      expect(subject).to have_text('Récupération des données en cours pour l’identifiant « 075-FDD-00003-01 »')
    end
  end

  context 'when the champ is in external error with a 404' do
    let(:external_state) { 'external_error' }
    let(:rnf_data) { nil }
    let(:fetch_external_data_exceptions) { [ExternalDataException.new(error: 'NotFound', code: 404)] }

    it 'displays a not found message with the identifier' do
      expect(subject).to have_text('Aucune donnée trouvée pour l’identifiant « 075-FDD-00003-01 »')
    end
  end

  context 'when the champ is in external error with a technical error' do
    let(:external_state) { 'external_error' }
    let(:rnf_data) { nil }
    let(:fetch_external_data_exceptions) { [ExternalDataException.new(error: 'Boom', code: 500)] }

    it 'displays a generic error message with the identifier' do
      expect(subject).to have_text('Une erreur est survenue lors de la récupération des données pour l’identifiant « 075-FDD-00003-01 »')
    end
  end

  context 'when the value is blank' do
    let(:external_state) { nil }
    let(:external_id) { nil }
    let(:rnf_data) { nil }

    it 'displays a not filled message' do
      expect(subject).to have_text('Non renseigné')
    end
  end
end
