# frozen_string_literal: true

require 'open3'

describe TypstService do
  describe 'attestation de dépôt' do
    let(:dossier) { dossiers.en_construction }
    let(:data) { Typst::AttestationDepotPayload.new(dossier).to_h }

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
      # (only explicit par() calls are queryable: the signature lines are, the description block is not)
      expect(document['paragraphs'].last(2)).to eq(data[:signature])
    end

    it 'carries payload strings through the entry document untouched', :external_deps do
      require_tool!('typst')

      # Quotes and backslashes are the two characters the Typst string literal
      # escapes, U+2028 the one script_safe JSON escapes; the rest is UTF-8.
      value = %(guillemets "doubles" et \\ antislash \\" mélangés, 'simples', # dièse, é 🙂 ligne séparée)
      payload = data.merge(sections: [{ title: 'Section', rows: [['Clé', value]] }])

      document = described_class.query('attestation_depot', payload, 'tables()')

      expect(document.first).to eq(['Clé', value])
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

  describe 'compilation root' do
    it 'ships the templates, their fonts and the default logos, and nothing else' do
      entries = Dir.glob('**/*', base: TypstService::ROOT).sort

      expect(entries).to eq([
        'attestation_depot.typ',
        'fonts',
        'fonts/marianne-bold.ttf',
        'fonts/marianne-regular-italic.ttf',
        'fonts/marianne-regular.ttf',
        'images',
        'images/Marianne-Light@2x.png',
        'images/logo-demarche-numerique@2x.png',
        'introspection.typ',
        'theme.typ',
      ])
    end

    # The whole point of the confined root: a template (or a compromised one)
    # cannot read the repository around it.
    it 'refuses to read outside of it', :external_deps do
      require_tool!('typst')

      Dir.mktmpdir('spec-escape', TypstService::ROOT) do |dir|
        File.write(File.join(dir, 'escape.typ'), '#let render(data) = read("/../config/database.yml")')

        expect { described_class.generate_pdf("#{File.basename(dir)}/escape", {}) }
          .to raise_error(described_class::Error, /would escape the project root/)
      end
    end

    # Typst does not synthesize italics: without a real italic face,
    # style: "italic" helper text silently renders upright.
    it 'ships an italic Marianne face', :external_deps do
      require_tool!('typst')

      variants = `typst fonts --font-path #{TypstService::FONTS_DIR} --ignore-system-fonts --variants`

      expect(variants).to include('fonts/marianne-regular-italic.ttf')
      expect(variants).to match(/marianne-regular-italic\.ttf\n.*Style: Italic, Weight: 400/)
    end
  end

  describe '.generate_pdf' do
    # The suite-wide rails_helper stub replaces generate_pdf itself; restore
    # the real method and stub the compiler invocation instead.
    before { allow(described_class).to receive(:generate_pdf).and_call_original }

    let(:success) { instance_double(Process::Status, success?: true) }

    def capture_invocation
      invocation = {}
      allow(Open3).to receive(:capture3) do |*args, **options|
        invocation[:argv] = args
        invocation[:source] = options[:stdin_data]
        ['%PDF-fake', '', success]
      end
      invocation
    end

    it 'compiles the entry document from stdin inside a temporary root' do
      invocation = capture_invocation

      pdf = described_class.generate_pdf('attestation_depot', { title: 'Titre' })

      expect(pdf).to eq('%PDF-fake')
      expect(invocation[:argv]).to match([
        'typst', 'compile',
        '--root', a_string_starting_with(Rails.root.join('tmp/typst').to_s),
        '--font-path', TypstService::FONTS_DIR.to_s,
        '--ignore-system-fonts',
        '--pdf-standard', 'ua-1',
        '-', '-',
      ])
      expect(invocation[:source]).to eq(%(#import "/attestation_depot.typ": render\n#render(json(bytes("{\\"title\\":\\"Titre\\"}")))\n))
    end

    it 'mirrors lib/typst/root in that temporary root, gone once compiled' do
      root = entries = nil
      allow(Open3).to receive(:capture3) do |*args, **|
        root = Pathname(args[args.index('--root') + 1])
        entries = root.children.sort.to_h { [it.basename.to_s, File.readlink(it)] }
        ['%PDF-fake', '', success]
      end

      described_class.generate_pdf('attestation_depot', {})

      expect(entries).to eq(TypstService::ROOT.children.sort.to_h { [it.basename.to_s, it.to_s] })
      expect(root).not_to be_exist
    end

    it 'escapes the payload into the Typst string literal' do
      invocation = capture_invocation

      described_class.generate_pdf('attestation_depot', { title: %(a "b" c\\d\ne f) })

      expect(invocation[:source]).to include(%(json(bytes("{\\"title\\":\\"a \\\\\\"b\\\\\\" c\\\\\\\\d\\\\ne\\\\u2028f\\"}"))))
    end

    it 'passes a large payload on stdin, keeping argv under the kernel per-argument limit' do
      invocation = capture_invocation

      described_class.generate_pdf('attestation_depot', { title: 'x' * 200_000 })

      expect(invocation[:source]).to include('x' * 200_000)
      expect(invocation[:argv].map(&:bytesize)).to all(be < 128.kilobytes)
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

  describe '.query' do
    let(:success) { instance_double(Process::Status, success?: true) }

    it 'evaluates the expression in the rendered template, with the introspection helpers in scope' do
      argv = source = nil
      allow(Open3).to receive(:capture3) do |*args, **options|
        argv = args
        source = options[:stdin_data]
        ['{"headings":[{"level":1,"text":"Titre"}]}', '', success]
      end

      result = described_class.query('attestation_depot', { title: 'Titre' }, 'headings()')

      expect(result).to eq('headings' => [{ 'level' => 1, 'text' => 'Titre' }])
      expect(argv[0..1]).to eq(['typst', 'eval'])
      expect(argv[argv.index('--in') + 1]).to eq('-')
      expect(argv.last).to include('import "/introspection.typ": *', 'headings()')
      expect(source).to start_with('#import "/attestation_depot.typ": render')
    end

    it 'raises the service error on an invalid expression' do
      allow(Open3).to receive(:capture3).and_return(['', 'error: unknown variable', instance_double(Process::Status, success?: false)])

      expect { described_class.query('attestation_depot', {}, 'nope()') }
        .to raise_error(described_class::Error, /document query failed: error: unknown variable/)
    end
  end
end
