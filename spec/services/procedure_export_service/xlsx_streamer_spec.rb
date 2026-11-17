# frozen_string_literal: true

describe ProcedureExportService::XlsxStreamer do
  let(:io) { Tempfile.new(['xlsx_streamer_spec', '.xlsx'], binmode: true) }

  after { io.close!; io.unlink rescue nil }

  def read_sheets
    io.rewind
    xlsx = SimpleXlsxReader.open(io.path)
    xlsx.sheets.each { |s| s.rows.slurp }
    xlsx
  end

  describe 'with a single sheet' do
    subject(:streamer) { described_class.new(io) }

    it 'writes headers and a row of values' do
      streamer.open do |writer|
        writer.write_sheet('Test', headers: ['A', 'B', 'C']) do |sheet|
          sheet.add_row(['hello', 42, nil])
        end
      end

      sheet = read_sheets.sheets.first
      expect(sheet.name).to eq('Test')
      expect(sheet.headers).to eq(['A', 'B', 'C'])
      expect(sheet.data).to eq([['hello', 42, nil]])
    end

    it 'coerces nil to empty string, symbol to string' do
      streamer.open do |writer|
        writer.write_sheet('S', headers: ['x']) do |sheet|
          sheet.add_row([nil])
          sheet.add_row([:foo])
        end
      end

      sheet = read_sheets.sheets.first
      expect(sheet.data).to eq([[nil], ['foo']])
    end
  end

  describe 'formula-like values' do
    subject(:streamer) { described_class.new(io) }

    it 'writes them verbatim as inert text (xlsx string cells are never evaluated)' do
      streamer.open do |writer|
        writer.write_sheet('S', headers: ['x']) do |sheet|
          sheet.add_row(['=1+1'])
          sheet.add_row(['+formula'])
          sheet.add_row(['-cmd'])
          sheet.add_row(['@dde'])
          sheet.add_row(["\tfoo"])
          sheet.add_row(["\rbar"])
          sheet.add_row(['safe'])
        end
      end

      sheet = read_sheets.sheets.first
      values = sheet.data.flatten
      # No leading "'" escape (unlike CSV): the values are stored as-is, matching
      # the previous caxlsx export. Note: XML normalizes \r to \n on serialization
      # (XML 1.0 spec), so SimpleXlsxReader gives back "\nbar" for the \r case.
      expect(values).to eq(['=1+1', '+formula', '-cmd', '@dde', "\tfoo", "\nbar", 'safe'])
    end
  end

  describe 'with multiple sheets' do
    subject(:streamer) { described_class.new(io) }

    it 'writes them sequentially in order' do
      streamer.open do |writer|
        writer.write_sheet('First', headers: ['a']) { |s| s.add_row([1]) }
        writer.write_sheet('Second', headers: ['b']) { |s| s.add_row([2]) }
      end

      expect(read_sheets.sheets.map(&:name)).to eq(['First', 'Second'])
    end
  end

  describe 'sheet name sanitization' do
    subject(:streamer) { described_class.new(io) }

    it 'replaces forbidden chars and truncates to 30 ASCII bytes' do
      raw = 'Élève / Dossier *[] très long ' * 3
      streamer.open do |writer|
        writer.write_sheet(raw, headers: ['x']) { |s| s.add_row(['v']) }
      end

      name = read_sheets.sheets.first.name
      expect(name.bytesize).to be <= 30
      expect(name).not_to match(%r{[/\\*?\[\]:]})
      expect(name).to eq(ProcedureExportService.sanitize_sheet_name(raw))
    end

    it 'strips the apostrophes Excel forbids at both ends, the truncation included' do
      expect(ProcedureExportService.sanitize_sheet_name("(4589041) Veuillez indiquer l'identité des participants")).to eq("(4589041) Veuillez indiquer l")
      expect(ProcedureExportService.sanitize_sheet_name("'Participants'")).to eq("Participants")
    end
  end

  describe 'styling and value types' do
    subject(:streamer) { described_class.new(io) }

    def read_zip_entry(name)
      io.rewind
      Zip::File.open(io.path) { |zip| zip.read(name) }
    end

    before do
      streamer.open do |writer|
        writer.write_sheet('Test', headers: ['Header A', 'Bool']) do |sheet|
          sheet.add_row(['text', true])
          sheet.add_row(['text2', false])
        end
      end
    end

    it 'writes a Ruby boolean as a native boolean cell (t="b")' do
      expect(read_sheets.sheets.first.data).to eq([['text', true], ['text2', false]])
    end

    it 'styles each header cell with a black fill and a white font' do
      styles = read_zip_entry('xl/styles.xml')
      expect(styles).to include('<fgColor rgb="FF000000"/>')
      expect(styles).to include('rgb="FFFFFFFF"')

      # Numbers honors cell-level styles, not row-level ones, so each header
      # cell must carry the style index directly.
      sheet_xml = read_zip_entry('xl/worksheets/sheet1.xml')
      expect(sheet_xml).to match(/<c r="A1" s="3"/)
      expect(sheet_xml).to match(/<c r="B1" s="3"/)
    end

    it 'declares the datetime format with unescaped code so readers recognize it as a date' do
      styles = read_zip_entry('xl/styles.xml')
      expect(styles).to include('formatCode="yyyy-mm-dd h:mm AM/PM"')
    end

    # caxlsx (previous export) styled Date columns with the custom code
    # "yyyy-mm-dd", not the locale-dependent built-in numFmtId 14.
    it 'declares the date format with a yyyy-mm-dd code matching the caxlsx export' do
      styles = read_zip_entry('xl/styles.xml')
      expect(styles).to include('formatCode="yyyy-mm-dd"')
    end

    it 'sets column widths' do
      sheet_xml = read_zip_entry('xl/worksheets/sheet1.xml')
      expect(sheet_xml).to match(/<col [^>]*width="[^"]+"[^>]*customWidth="1"/)
    end
  end

  describe '.column_widths' do
    it 'sizes a column to its longest content when it exceeds the header' do
      expect(described_class.column_widths(['Email'], [['a@b.fr'], ['a' * 40]])).to eq([40])
    end

    it 'falls back to the header length when the content is shorter' do
      expect(described_class.column_widths(['A long-ish header'], [['x']])).to eq(['A long-ish header'.length])
    end

    it 'clamps tiny header and content up to MIN_WIDTH' do
      expect(described_class.column_widths(['x'], [['y']])).to eq([described_class::MIN_WIDTH])
    end

    it 'caps very long content at MAX_WIDTH' do
      expect(described_class.column_widths(['h'], [['x' * 150]])).to eq([described_class::MAX_WIDTH])
    end

    it 'sizes dates and datetimes by their rendered format, not #to_s' do
      widths = described_class.column_widths(['d', 'dt'], [[Date.new(2026, 1, 2), Time.zone.local(2026, 1, 2, 3, 4)]])
      # date -> "yyyy-mm-dd" (10, clamped up to MIN_WIDTH), datetime -> "yyyy-mm-dd h:mm AM/PM" (20)
      expect(widths).to eq([described_class::MIN_WIDTH, 20])
    end

    it 'ignores nil cells when sizing' do
      expect(described_class.column_widths(['h'], [[nil], ['x' * 40]])).to eq([40])
    end
  end
end
