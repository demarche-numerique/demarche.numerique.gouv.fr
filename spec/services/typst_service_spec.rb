# frozen_string_literal: true

require 'open3'

describe TypstService do
  describe 'attestation de dépôt' do
    let(:dossier) { dossiers.en_construction }
    let(:data) { dossier.attestation_depot_typst_data }

    it 'builds the document payload from the dossier' do
      expect(data[:title]).to eq('Attestation de dépôt')
      expect(data[:procedure]).to eq(dossier.procedure.libelle)
      expect(data[:description]).to include('Jeanne DUPONT')
      expect(data[:sections].map { it[:title] })
        .to eq(['Identité du demandeur', 'Dossier', 'Service administratif'])
      expect(data[:sections].first[:rows]).to include(['Prénom', 'Jeanne'], ['Nom', 'DUPONT'])
      expect(data[:sections].second[:rows].first).to eq(['Numéro de dossier', dossier.id.to_s])
    end

    it 'references header logos that exist on disk' do
      paths = [data[:logo], data[:marianne]].compact.map { it[:path] }

      expect(paths).to all(start_with('/app/assets/images/'))
      paths.each { expect(Rails.root.join(it.delete_prefix('/'))).to be_exist }
    end

    it 'resolves an ENV-configured logo across the asset load paths' do
      # (a load path outside app/assets/images, inside the Rails root; CI unit
      # jobs restore precompiled assets without node_modules, so a DSFR artwork
      # file is not a reliable target here)
      Dir.mktmpdir('typst-assets', Rails.root.join('tmp')) do |dir|
        FileUtils.touch(File.join(dir, 'custom-logo.svg'))
        allow(Rails.application.config.assets).to receive(:paths).and_wrap_original { |m| m.call + [dir] }
        stub_const('LOGO_SRC', 'custom-logo.svg')

        expect(data[:logo][:path]).to eq("/tmp/#{File.basename(dir)}/custom-logo.svg")
      end
    end

    it 'omits a logo it cannot find instead of failing the generation' do
      stub_const('LOGO_MARIANNE_SRC', 'missing-logo.png')

      expect(data[:marianne][:path]).to be_nil
    end

    it 'renders a PDF that passes veraPDF PDF/UA-1 validation', :external_deps do
      require_tool!('typst')

      pdf = described_class.generate_pdf('attestation_depot', data)

      expect(pdf[0, 5]).to eq('%PDF-')

      require_tool!('verapdf')

      Tempfile.create(['attestation_depot', '.pdf']) do |file|
        file.binmode
        file.write(pdf)
        file.flush

        # (stderr holds only JVM noise; the text report lands on stdout)
        report, warnings, = Open3.capture3('verapdf', '--format', 'text', '--flavour', 'ua1', file.path)

        expect(report).to start_with('PASS'), -> { "veraPDF PDF/UA-1 validation failed:\n#{report}\n#{warnings}" }
      end
    end

    it 'raises on payloads the template cannot render', :external_deps do
      require_tool!('typst')

      expect { described_class.generate_pdf('attestation_depot', {}) }
        .to raise_error(described_class::Error, /PDF generation failed/)
    end
  end

  describe 'fonts' do
    # Typst does not synthesize italics: without a real italic face,
    # style: "italic" helper text silently renders upright.
    it 'ships an italic Marianne face', :external_deps do
      require_tool!('typst')

      variants = `typst fonts --font-path #{TypstService::FONTS_DIR} --ignore-system-fonts --variants`

      expect(variants).to include('marianne/marianne-regular-italic.ttf')
      expect(variants).to match(/marianne-regular-italic\.ttf\n.*Style: Italic, Weight: 400/)
    end
  end

  describe '.generate_pdf' do
    # The suite-wide rails_helper stub replaces generate_pdf itself; restore
    # the real method and stub the compiler invocation instead.
    before { allow(described_class).to receive(:generate_pdf).and_call_original }

    let(:success) { instance_double(Process::Status, success?: true) }

    it 'passes a large payload through a tempfile, keeping argv under the kernel per-argument limit' do
      data = { title: 'x' * 200_000 }
      argv = payload = nil
      allow(Open3).to receive(:capture3) do |*args, **|
        argv = args
        path = args[args.index('--input') + 1].delete_prefix('data=')
        payload = Rails.root.join(path.delete_prefix('/')).read
        ['%PDF-fake', '', success]
      end

      pdf = described_class.generate_pdf('attestation_depot', data)

      expect(pdf).to eq('%PDF-fake')
      expect(payload).to eq(JSON.generate(data))
      expect(argv.map(&:bytesize)).to all(be < 128.kilobytes)
    end

    it 'wraps a missing typst binary in the service error class' do
      allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT.new('typst'))

      expect { described_class.generate_pdf('attestation_depot', {}) }
        .to raise_error(described_class::Error, /PDF generation failed/)
    end
  end
end
