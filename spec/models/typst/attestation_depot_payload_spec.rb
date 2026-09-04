# frozen_string_literal: true

describe Typst::AttestationDepotPayload do
  let(:dossier) { dossiers.en_construction }
  let(:data) { described_class.new(dossier).to_h }

  it 'is named after its template' do
    expect(described_class.template).to eq('attestation_depot')
    expect(TypstService::ROOT.join('attestation_depot.typ')).to be_file
  end

  it 'builds the document payload from the dossier' do
    expect(data[:title]).to eq('Attestation de dépôt')
    expect(data[:procedure]).to eq(dossier.procedure.libelle)
    expect(data[:description]).to include('Jeanne DUPONT')
    expect(data[:sections].map { it[:title] })
      .to eq(['Identité du demandeur', 'Dossier', 'Service administratif'])
    expect(data[:sections].first[:rows]).to include(['Prénom', 'Jeanne'], ['Nom', 'DUPONT'])
    expect(data[:sections].second[:rows].first).to eq(['Numéro de dossier', dossier.id.to_s])
  end

  it 'references header logos shipped in the compilation root' do
    paths = [data[:logo], data[:marianne]].compact.map { it[:path] }

    expect(paths).to all(start_with('/images/'))
    paths.each { expect(TypstService::ROOT.join(it.delete_prefix('/'))).to be_file }
  end

  it 'resolves a custom logo copied under the images directory' do
    Dir.mktmpdir('spec-assets', TypstService::IMAGES_DIR) do |dir|
      FileUtils.touch(File.join(dir, 'custom-logo.svg'))
      stub_const('LOGO_SRC', "#{File.basename(dir)}/custom-logo.svg")

      expect(data[:logo][:path]).to eq("/images/#{File.basename(dir)}/custom-logo.svg")
    end
  end

  it 'omits a logo it cannot find instead of failing the generation' do
    stub_const('LOGO_MARIANNE_SRC', 'missing-logo.png')

    expect(data[:marianne][:path]).to be_nil
  end

  # The web layouts resolve LOGO_SRC across the asset load paths; the PDFs
  # only embed what the compilation root holds.
  it 'does not reach for an image outside the images directory' do
    stub_const('LOGO_SRC', '../theme.typ')
    stub_const('LOGO_MARIANNE_SRC', '../../../../app/assets/images/Marianne-Light@2x.png')

    expect(data[:logo][:path]).to be_nil
    expect(data[:marianne][:path]).to be_nil
  end

  # Known limitation of the file resolver: a remote logo (the web layouts
  # accept a URL through image_url) renders as the alt-text placeholder.
  it 'leaves a URL-configured logo unresolved' do
    stub_const('LOGO_SRC', 'https://cdn.exemple.fr/logo.png')

    expect(data[:logo][:path]).to be_nil
  end

  context 'instance without a Marianne block (empty LOGO_MARIANNE_SRC)' do
    before { stub_const('LOGO_MARIANNE_SRC', '') }

    it 'omits the block entirely instead of rendering an empty frame' do
        expect(data[:marianne]).to be_nil
      end
  end

  context 'instance with a Marianne block' do
    before { stub_const('LOGO_MARIANNE_SRC', 'Marianne-Light@2x.png') }

    it 'resolves it with its alt text' do
        expect(data[:marianne]).to eq(path: '/images/Marianne-Light@2x.png', alt: 'Logo Marianne, République Française')
      end
  end

  context 'without DIRECTION_LABEL (empty default)' do
    before { stub_const('DIRECTION_LABEL', '') }

    it 'omits the direction line and keeps the site name' do
        expect(data[:direction_label]).to be_nil
        expect(data[:direction_site]).to eq(APPLICATION_NAME)
      end
  end

  context 'with DIRECTION_LABEL' do
    before { stub_const('DIRECTION_LABEL', 'Direction Interministérielle du Numérique') }

    it { expect(data[:direction_label]).to eq('Direction Interministérielle du Numérique') }
  end
end
