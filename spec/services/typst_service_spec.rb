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
        expect(data[:marianne]).to eq(path: '/app/assets/images/Marianne-Light@2x.png', alt: 'Logo Marianne, République Française')
      end
    end

    context 'without DIRECTION_LABEL (empty default)' do
      before { stub_const('DIRECTION_LABEL', '') }

      it 'signs the footer with the site name alone' do
        expect(data[:sender]).to eq([APPLICATION_NAME])
      end
    end

    context 'with DIRECTION_LABEL' do
      before { stub_const('DIRECTION_LABEL', 'Direction Interministérielle du Numérique') }

      it { expect(data[:sender]).to eq(['Direction Interministérielle du Numérique', APPLICATION_NAME]) }
    end

    it 'lays out the title, the sections and the identity rows', :external_deps do
      require_tool!('typst')

      document = described_class.query('attestation_depot', data, '(headings: headings(), tables: tables(), paragraphs: paragraphs())')

      expect(document['headings']).to eq([
        { 'level' => 1, 'text' => 'Attestation de dépôt' },
        { 'level' => 2, 'text' => 'Identité du demandeur' },
        { 'level' => 2, 'text' => 'Dossier' },
        { 'level' => 2, 'text' => 'Service administratif' },
      ])
      expect(document['tables'].first).to include('Prénom', 'Jeanne', 'Nom', 'DUPONT')
      expect(document['tables'].second).to start_with('Numéro de dossier', dossier.id.to_s)
      # (only explicit par() calls are queryable: the footer and signature lines are, the description block is not)
      expect(document['paragraphs']).to include(data[:signature], *data[:sender])
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
    # Typst does not synthesize styles: without a real face, style: "italic"
    # helper text silently renders upright, weight: "light" as regular, and a
    # strong inside an italic description as plain italic.
    it 'ships the light, italic and bold italic Marianne faces', :external_deps do
      require_tool!('typst')

      variants = `typst fonts --font-path #{TypstService::FONTS_DIR} --ignore-system-fonts --variants`

      expect(variants).to match(/marianne-light\.ttf\n.*Style: Normal, Weight: 300/)
      expect(variants).to match(/marianne-regular-italic\.ttf\n.*Style: Italic, Weight: 400/)
      expect(variants).to match(/marianne-bold-italic\.ttf\n.*Style: Italic, Weight: 700/)
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

    it 'wraps a non-executable binary or an unwritable tmp/ in the service error class' do
      allow(Open3).to receive(:capture3).and_raise(Errno::EACCES.new('typst'))

      expect { described_class.generate_pdf('attestation_depot', {}) }
        .to raise_error(described_class::Error, /PDF generation failed: Permission denied/)
    end
  end

  describe '.with_assets' do
    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(io: Rails.root.join('spec/fixtures/files/image-no-exif.jpg').open, filename: 'carte.jpg', content_type: 'image/jpeg')
    end

    it 'downloads a blob under the compilation root for the duration of the block' do
      asset = nil

      described_class.with_assets do |assets|
        asset = assets.image(blob, alt: 'Carte de la zone')

        expect(asset).to match(path: start_with('/tmp/typst-assets'), alt: 'Carte de la zone')
        expect(asset[:path]).to end_with('.jpg')
        expect(Rails.root.join(asset[:path].delete_prefix('/')).binread).to eq(blob.download)
      end

      expect(Rails.root.join(asset[:path].delete_prefix('/'))).not_to be_exist
    end

    it 'reads an attachment through its blob and returns nil for an empty one' do
      procedure = Procedure.new
      procedure.logo.attach(blob)

      described_class.with_assets do |assets|
        expect(assets.image(procedure.logo, alt: 'Logo')).to include(alt: 'Logo')
        expect(assets.image(Procedure.new.logo, alt: 'Logo')).to be_nil
        expect(assets.image(nil, alt: 'Logo')).to be_nil
      end
    end

    it 'embeds the image with its alt text in a PDF/UA-1 document', :external_deps do
      require_tool!('typst')

      Dir.mktmpdir('typst-templates', Rails.root.join('tmp')) do |dir|
        File.write(File.join(dir, 'illustration.typ'), <<~TYPST)
          #import "/lib/typst/theme.typ": *
          #let data = json(sys.inputs.data)
          #show: letterhead.with(title: "Illustration", marianne: data.marianne, logo: data.logo, sender: data.sender)
          #heading(level: 1)[Carte]
          #illustration(data.map)
        TYPST
        stub_const('TypstService::TEMPLATES_DIR', Pathname(dir))

        described_class.with_assets do |assets|
          data = { **described_class.letterhead, map: assets.image(blob, alt: 'Carte de la zone') }

          expect(described_class.query('illustration', data, 'images()')).to include('alt' => 'Carte de la zone')

          pdf = described_class.generate_pdf('illustration', data)
          expect(pdf[0, 5]).to eq('%PDF-')

          require_tool!('verapdf')

          Tempfile.create(['illustration', '.pdf']) do |file|
            file.binmode
            file.write(pdf)
            file.flush

            report, warnings, = Open3.capture3('verapdf', '--format', 'text', '--flavour', 'ua1', file.path)

            expect(report).to start_with('PASS'), -> { "veraPDF PDF/UA-1 validation failed:\n#{report}\n#{warnings}" }
          end
        end
      end
    end
  end

  describe '.query' do
    let(:success) { instance_double(Process::Status, success?: true) }

    it 'evaluates the expression in the rendered template, with the introspection helpers in scope' do
      argv = nil
      allow(Open3).to receive(:capture3) do |*args, **|
        argv = args
        ['{"headings":[{"level":1,"text":"Titre"}]}', '', success]
      end

      result = described_class.query('attestation_depot', { title: 'Titre' }, 'headings()')

      expect(result).to eq('headings' => [{ 'level' => 1, 'text' => 'Titre' }])
      expect(argv[0..1]).to eq(['typst', 'eval'])
      expect(argv[argv.index('--in') + 1]).to eq(TypstService::TEMPLATES_DIR.join('attestation_depot.typ').to_s)
      expect(argv.last).to include('import "/lib/typst/introspection.typ": *', 'headings()')
    end

    it 'raises the service error on an invalid expression' do
      allow(Open3).to receive(:capture3).and_return(['', 'error: unknown variable', instance_double(Process::Status, success?: false)])

      expect { described_class.query('attestation_depot', {}, 'nope()') }
        .to raise_error(described_class::Error, /document query failed: error: unknown variable/)
    end
  end
end
