# frozen_string_literal: true

require 'open3'

describe PdfProfile::TypstCompiler do
  let(:fixture) { Rails.root.join('spec/fixtures/pdf_profile/attestation_depot.html').read }

  describe '.compile' do
    subject(:typ) { described_class.compile(fixture) }

    it 'compiles the attestation de dépôt corpus to the golden Typst source' do
      golden = Rails.root.join('spec/fixtures/pdf_profile/attestation_depot.typ')
      golden.write(typ) if ENV['PDF_PROFILE_DUMP'] == '1'

      expect(typ).to eq(golden.read)
    end

    it 'produces a document Typst accepts as PDF/UA-1' do
      skip 'typst binary not installed' unless system('which typst', out: File::NULL, err: File::NULL)

      Dir.mktmpdir do |dir|
        FileUtils.cp(Rails.root.join('lib/typst/theme.typ'), dir)
        File.write(File.join(dir, 'main.typ'), typ)

        output, status = Open3.capture2e(
          'typst', 'compile',
          '--pdf-standard', 'ua-1',
          '--font-path', Rails.root.join('lib/prawn/fonts').to_s,
          File.join(dir, 'main.typ'),
          File.join(dir, 'out.pdf')
        )

        expect(status).to be_success, -> { "typst compile failed:\n#{output}" }
        expect(output).not_to include('warning'), -> { "typst emitted warnings:\n#{output}" }
        expect(File.binread(File.join(dir, 'out.pdf'), 5)).to eq('%PDF-')
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
end
