# frozen_string_literal: true

describe 'lint:french_quotes' do
  let(:rake_task) { Rake::Task['lint:french_quotes'] }
  let(:temp_file) { File.join(Dir.mktmpdir, 'test.fr.yml') }

  before do
    allow(Dir).to receive(:glob).with('{config/locales,app/components}/**/{*.fr,fr}.yml').and_return([temp_file])
    File.write(temp_file, yaml)
  end

  after { rake_task.reenable }

  context 'with « » and HTML attributes' do
    let(:yaml) do
      <<~YAML
        fr:
          title: "Le groupe « %{name} »"
          link_html: '<a href="%{url}" class="fr-link">l’aide</a>'
      YAML
    end

    it { expect { rake_task.invoke }.to output(/No “ ”, " " or ‘ ’ found/).to_stdout }
  end

  context 'with forbidden quotes' do
    let(:yaml) do
      <<~YAML
        fr:
          straight: 'Le groupe "%{name}"'
          english: "La démarche “%{libelle}”"
          single: "‘Désolé’"
          prefill_query_response_html: '{ "dossier_url": "%{url}" }'
      YAML
    end

    it 'reports each translation and exits with 1' do
      expect { rake_task.invoke }
        .to raise_error(SystemExit) { expect(it.status).to eq(1) }
        .and output(/fr\.straight.*fr\.english.*fr\.single.*Found 3 translation/m).to_stdout
    end
  end
end
