# frozen_string_literal: true

RSpec.describe Dossiers::RNAComponent, type: :component do
  let(:fetch_external_data_exceptions) { [] }

  let(:external_id) { 'W173847273' }

  let(:champ) do
    build_projected_champ(build(:type_de_champ_rna), external_state:, external_id:, data: rna_data, fetch_external_data_exceptions:)
      .tap { |c| allow(c).to receive(:to_s).and_return('W173847273') }
  end

  subject { render_inline(described_class.new(champ:)) }

  before do
    allow(Dossiers::ExternalChampComponent).to receive(:new).and_call_original
    subject
  end

  context 'when the data is fetched?' do
    let(:external_state) { 'fetched' }
    let(:rna_data) do
      {
        'association_titre' => 'LA PRÉVENTION ROUTIÈRE',
        'association_objet' => 'Prévention des accidents de la route',
        'association_date_creation' => '1949-01-01',
      }
    end

    it 'renders ExternalChampComponent with correct arguments' do
      expect(Dossiers::ExternalChampComponent).to have_received(:new) do |data:, details:, source:|
        expect(data).to include(['Numéro RNA', 'W173847273'])
        expect(data).to include(['Nom de l’association', 'LA PRÉVENTION ROUTIÈRE'])
        expect(data).to include(['Objet de l’association', 'Prévention des accidents de la route'])
        expect(details).to include(['Date de création', '1949-01-01'])
        expect(source.to_s).to include('RNA')
      end
    end
  end

  context 'when the champ is waiting for a job' do
    let(:external_state) { 'waiting_for_job' }
    let(:rna_data) { nil }

    it 'displays a pending message with the identifier' do
      expect(subject).to have_text('Récupération des données en cours pour l’identifiant « W173847273 »')
    end
  end

  context 'when the champ is in external error with a 404' do
    let(:external_state) { 'external_error' }
    let(:rna_data) { nil }
    let(:fetch_external_data_exceptions) { [ExternalDataException.new(error: 'NotFound', code: 404)] }

    it 'displays a not found message with the identifier' do
      expect(subject).to have_text('Aucune donnée trouvée pour l’identifiant « W173847273 »')
    end
  end

  context 'when the champ is in external error with a technical error' do
    let(:external_state) { 'external_error' }
    let(:rna_data) { nil }
    let(:fetch_external_data_exceptions) { [ExternalDataException.new(error: 'Boom', code: 500)] }

    it 'displays a generic error message with the identifier' do
      expect(subject).to have_text('Une erreur est survenue lors de la récupération des données pour l’identifiant « W173847273 »')
    end
  end

  context 'when the external_id is blank' do
    let(:external_state) { nil }
    let(:external_id) { nil }
    let(:rna_data) { nil }

    it 'displays a not filled message' do
      expect(subject).to have_text('Non renseigné')
    end
  end
end
