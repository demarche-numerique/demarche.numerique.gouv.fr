# frozen_string_literal: true

require 'open3'

describe PdfProfile::TypstCompiler do
  let(:fixture) { Rails.root.join('spec/fixtures/pdf_profile/attestation_depot.html').read }
  let(:image_assets) { described_class.image_assets(fixture) }
  let(:assets) { image_assets.transform_values { "assets/#{it[:name]}" } }

  describe '.compile' do
    subject(:typ) { described_class.compile(fixture, assets:) }

    it 'compiles the attestation de dépôt corpus to the golden Typst source' do
      golden = Rails.root.join('spec/fixtures/pdf_profile/attestation_depot.typ')
      golden.write(typ) if ENV['PDF_PROFILE_DUMP'] == '1'

      expect(typ).to eq(golden.read)
    end

    it 'produces a document Typst accepts as PDF/UA-1', :external_deps do
      skip 'typst binary not installed' unless installed?('typst')

      Dir.mktmpdir do |dir|
        pdf, output, status = compile_pdf(dir)

        expect(status).to be_success, -> { "typst compile failed:\n#{output}" }
        expect(output).not_to include('warning'), -> { "typst emitted warnings:\n#{output}" }
        expect(File.binread(pdf, 5)).to eq('%PDF-')
      end
    end

    it 'passes veraPDF PDF/UA-1 validation', :external_deps do
      skip 'typst binary not installed' unless installed?('typst')
      skip 'verapdf binary not installed' unless installed?('verapdf')

      Dir.mktmpdir do |dir|
        pdf, output, status = compile_pdf(dir)
        expect(status).to be_success, -> { "typst compile failed:\n#{output}" }

        # (stderr holds only JVM noise; the text report lands on stdout)
        report, warnings, = Open3.capture3('verapdf', '--format', 'text', '--flavour', 'ua1', pdf)

        expect(report).to start_with('PASS'), -> { "veraPDF PDF/UA-1 validation failed:\n#{report}\n#{warnings}" }
      end
    end

    it 'raises on HTML outside the implemented profile subset' do
      expect { described_class.compile('<body><table><tr><td>x</td></tr></table></body>') }
        .to raise_error(described_class::Error, /unsupported element/)
    end

    it 'raises on inline styles (not implemented yet)' do
      expect { described_class.compile('<body><p style="text-align: center">x</p></body>') }
        .to raise_error(described_class::Error, /style attribute/)
    end

    it 'raises on images without alt text' do
      expect { described_class.compile('<body><img class="marianne-with-devise" src="x.png"></body>') }
        .to raise_error(described_class::Error, /alt/)
    end

    it 'escapes Typst markup characters in text' do
      typ = described_class.compile('<body><p>#import $calc & 100_0 *gras* [x] @ref</p></body>')

      expect(typ).to include('#par[\#import \$calc \& 100\_0 \*gras\* \[x\] \@ref]')
    end

    it 'escapes quotes and backslashes in Typst string literals' do
      typ = described_class.compile(<<~HTML)
        <html><head><title>Attestation "spéciale" \\ 2026</title></head><body></body></html>
      HTML

      expect(typ).to include('title: "Attestation \"spéciale\" \\\\ 2026"')
    end
  end

  describe '.image_assets' do
    it 'resolves every corpus image to a file on disk' do
      expect(image_assets.values).to all(satisfy { it[:path].exist? })
      expect(image_assets.values.map { it[:name] })
        .to contain_exactly('Marianne-Light@2x.png', 'logo-demarche-numerique@2x.png')
    end

    it 'raises on unresolvable images' do
      expect { described_class.image_assets('<body><img src="/assets/nope-000.png" alt="x"></body>') }
        .to raise_error(described_class::Error, /cannot resolve/)
    end
  end

  private

  def installed?(binary)
    system("which #{binary}", out: File::NULL, err: File::NULL)
  end

  # Assembles a compilation directory (theme, resolved assets, main.typ) and
  # compiles it with the PDF/UA-1 standard enforced.
  def compile_pdf(dir)
    FileUtils.cp(Rails.root.join('lib/typst/theme.typ'), dir)

    assets_dir = File.join(dir, 'assets')
    FileUtils.mkdir_p(assets_dir)
    image_assets.each_value { FileUtils.cp(it[:path], File.join(assets_dir, it[:name])) }

    File.write(File.join(dir, 'main.typ'), typ)
    pdf = File.join(dir, 'out.pdf')

    output, status = Open3.capture2e(
      'typst', 'compile',
      '--pdf-standard', 'ua-1',
      '--font-path', Rails.root.join('lib/prawn/fonts').to_s,
      File.join(dir, 'main.typ'),
      pdf
    )

    [pdf, output, status]
  end
end
