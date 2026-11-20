# frozen_string_literal: true

describe 'lint:french_quotes' do
  let(:rake_task) { Rake::Task['lint:french_quotes'] }
  let(:temp_file) { File.join(Dir.mktmpdir, 'test.fr.yml') }

  before do
    allow(Dir).to receive(:glob).with('{config/locales,app/components}/**/{*.fr,fr}.yml').and_return([temp_file])
    File.write(temp_file, yaml)
  end

  after { rake_task.reenable }

  context 'with « » around non-breaking spaces and HTML attributes' do
    let(:yaml) do
      <<~YAML
        fr:
          nbsp: "Le groupe « %{name} »"
          narrow_nbsp: "Le groupe « %{name} »"
          entity_html: "Le groupe «&nbsp;%{name}&#160;»"
          link_html: '<a href="%{url}" class="fr-link">l’aide</a>'
      YAML
    end

    it { expect { rake_task.invoke }.to output(/No misused quotation marks found/).to_stdout }
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

  context 'with « » without non-breaking spaces inside' do
    let(:yaml) do
      <<~YAML
        fr:
          regular_space: "Le groupe « %{name} »"
          no_space: "Le groupe «%{name}»"
          opening_only: "Le groupe « %{name} »"
      YAML
    end

    it 'reports each translation and exits with 1' do
      expect { rake_task.invoke }
        .to raise_error(SystemExit) { expect(it.status).to eq(1) }
        .and output(/fr\.regular_space.*fr\.no_space.*fr\.opening_only.*Found 3 translation/m).to_stdout
    end
  end
end
