# frozen_string_literal: true

require 'csv'

describe ProcedureExportService::CsvExport do
  describe 'AS_TEXT' do
    {
      '=HYPERLINK("https://example.com","clic")' => %q('=HYPERLINK("https://example.com","clic")),
      '@SUM(1;2)' => "'@SUM(1;2)",
      "=1+1\n=A1" => "'=1+1\n=A1",
      '＝A1' => "'＝A1",
      '=1+1' => '=1+1',
      '- point 1' => '- point 1',
      '+33 6 12 34 56 78' => '+33 6 12 34 56 78',
      'jean@exemple.fr' => 'jean@exemple.fr',
    }.each do |value, expected|
      it "writes #{value.inspect} as #{expected.inspect}" do
        expect(described_class::AS_TEXT.call(value)).to eq(expected)
      end
    end

    it 'keeps non-string values' do
      expect(described_class::AS_TEXT.call(12)).to eq(12)
    end
  end

  describe '#write_to' do
    let(:procedure) { procedures.individual }
    let(:dossier) { dossiers.en_construction }
    let(:champ) { dossier.root_champs_public.find { it.libelle == 'Nom du projet' } }

    before do
      champ.type_de_champ.update!(libelle: '=Nom du projet')
      champ.update!(value: '=HYPERLINK("https://example.com","clic")')
    end

    it 'writes headers and values as text' do
      io = StringIO.new
      described_class.new(procedure:, dossiers: Dossier.where(id: dossier), export_template: nil).write_to(io)

      row = CSV.parse(io.string, headers: true).first
      expect(row["'=Nom du projet"]).to eq(%q('=HYPERLINK("https://example.com","clic")))
    end
  end
end
