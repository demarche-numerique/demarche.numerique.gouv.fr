# frozen_string_literal: true

describe 'lint:apostrophe' do
  let(:rake_task) { Rake::Task['lint:apostrophe'] }
  let(:temp_dir) { Dir.mktmpdir }
  let(:temp_file) { File.join(temp_dir, 'test.fr.yml') }

  # U+0027 SIMPLE QUOTE (incorrect)
  let(:bad_apos) { "'" }
  # U+2019 RIGHT APOSTROPHE (correct)
  let(:good_apos) { "\u2019" }

  before do
    # Stub Dir.glob to only return our temp file for the first pattern, empty for others
    allow(Dir).to receive(:glob).with('config/locales/**/*.fr.yml').and_return([temp_file])
    allow(Dir).to receive(:glob).with('config/locales/**/fr.yml').and_return([])
    allow(Dir).to receive(:glob).with('app/components/**/*.fr.yml').and_return([])
  end

  after do
    rake_task.reenable
  end

  context 'when file contains correct apostrophes (U+2019)' do
    before do
      File.write(temp_file, <<~YAML)
        fr:
          test:
            message: "Ce n#{good_apos}est pas d#{good_apos}un type accepté"
            autre: "L#{good_apos}exemple de l#{good_apos}utilisateur"
      YAML
    end

    it 'passes without error' do
      expect { rake_task.invoke }.to output(/No incorrect apostrophes found/).to_stdout
    end
  end

  context 'when file contains incorrect apostrophes (U+0027)' do
    before do
      File.write(temp_file, <<~YAML)
        fr:
          test:
            message: "Ce n#{bad_apos}est pas d#{bad_apos}un type accepté"
      YAML
    end

    it 'fails and reports the offenses' do
      expect {
        begin
          rake_task.invoke
        rescue SystemExit
          # Expected
        end
      }.to output(/Found 2 incorrect apostrophe/).to_stdout
    end

    it 'exits with code 1' do
      expect { rake_task.invoke }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
    end
  end

  context 'when file contains mixed apostrophes' do
    before do
      File.write(temp_file, <<~YAML)
        fr:
          test:
            correct: "L#{good_apos}exemple correct"
            incorrect: "L#{bad_apos}exemple incorrect"
      YAML
    end

    it 'reports only the incorrect ones' do
      expect {
        begin
          rake_task.invoke
        rescue SystemExit
          # Expected
        end
      }.to output(/Found 1 incorrect apostrophe/).to_stdout
    end
  end

  context 'when apostrophe is used as quote delimiter (not elision)' do
    before do
      # U+0027 used as YAML string delimiter or in HTML attributes, not as French apostrophe
      File.write(temp_file, <<~YAML)
        fr:
          test:
            message: 'This is a quoted string'
            html: "<span class='my-class'>text</span>"
      YAML
    end

    it 'does not report false positives' do
      expect { rake_task.invoke }.to output(/No incorrect apostrophes found/).to_stdout
    end
  end

  describe 'elision patterns' do
    context "with single letter elisions (l', d', n', etc.)" do
      before do
        File.write(temp_file, <<~YAML)
          fr:
            test:
              l_apostrophe: "l#{bad_apos}exemple"
              d_apostrophe: "d#{bad_apos}abord"
              n_apostrophe: "n#{bad_apos}est"
              s_apostrophe: "s#{bad_apos}il"
              c_apostrophe: "c#{bad_apos}est"
              j_apostrophe: "j#{bad_apos}ai"
              m_apostrophe: "m#{bad_apos}appelle"
              t_apostrophe: "t#{bad_apos}inquiète"
        YAML
      end

      it 'detects all incorrect elisions' do
        expect {
          begin
            rake_task.invoke
          rescue SystemExit
            # Expected
          end
        }.to output(/Found 8 incorrect apostrophe/).to_stdout
      end
    end

    context "with qu' elisions" do
      before do
        File.write(temp_file, <<~YAML)
          fr:
            test:
              quil: "qu#{bad_apos}il"
              quelle: "qu#{bad_apos}elle"
        YAML
      end

      it 'detects incorrect qu elisions' do
        expect {
          begin
            rake_task.invoke
          rescue SystemExit
            # Expected
          end
        }.to output(/Found 2 incorrect apostrophe/).to_stdout
      end
    end

    context "aujourd'hui" do
      before do
        File.write(temp_file, <<~YAML)
          fr:
            test:
              aujourdhui: "aujourd#{bad_apos}hui"
        YAML
      end

      it 'detects incorrect aujourdhui' do
        expect {
          begin
            rake_task.invoke
          rescue SystemExit
            # Expected
          end
        }.to output(/Found 1 incorrect apostrophe/).to_stdout
      end
    end
  end

  describe 'FIX mode' do
    before do
      File.write(temp_file, <<~YAML)
        fr:
          test:
            message: "Ce n#{bad_apos}est pas d#{bad_apos}un type accepté"
      YAML
    end

    around do |example|
      ENV['FIX'] = '1'
      example.run
      ENV['FIX'] = nil
    end

    it 'fixes incorrect apostrophes and does not exit with error' do
      expect { rake_task.invoke }.to output(/Fixed 2 incorrect apostrophe/).to_stdout

      fixed_content = File.read(temp_file)
      expect(fixed_content).to include("n#{good_apos}est")
      expect(fixed_content).to include("d#{good_apos}un")
      expect(fixed_content).not_to include("n#{bad_apos}est")
      expect(fixed_content).not_to include("d#{bad_apos}un")
    end
  end
end
