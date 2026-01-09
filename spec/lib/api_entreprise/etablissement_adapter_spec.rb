# frozen_string_literal: true

describe APIEntreprise::EtablissementAdapter do
  let(:procedure) { create(:procedure) }
  let(:procedure_id) { procedure.id }

  before do
    allow_any_instance_of(APIEntrepriseToken).to receive(:expired?).and_return(false)
  end

  context 'SIRET valide avec infos diffusables' do
    let(:siret) { '30613890001294' }
    let(:fixture) { 'spec/fixtures/files/api_entreprise/etablissements.json' }
    subject { described_class.new(siret, procedure_id).to_params }

    before do
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v3\/insee\/sirene\/etablissements\/#{siret}/)
        .to_return(body: File.read(fixture, status: 200))
    end

    it '#to_params class est une Hash ?' do
      expect(subject).to be_a_instance_of(Hash)
    end

    context 'Attributs Etablissements' do
      it 'L’entreprise contient bien un siret' do
        expect(subject[:siret]).to eq(siret)
      end

      it 'L’entreprise contient bien un siege_social' do
        expect(subject[:siege_social]).to eq(true)
      end

      it 'L’entreprise contient bien un naf' do
        expect(subject[:naf]).to eq('8411Z')
      end

      it 'L’entreprise contient bien un libelle_naf' do
        expect(subject[:libelle_naf]).to eq('Administration publique générale')
      end

      it 'L’entreprise contient bien un diffusable_commercialement qui vaut true' do
        expect(subject[:diffusable_commercialement]).to eq(true)
      end

      context 'Concaténation lignes adresse' do
        it 'L’entreprise contient bien une adresse sur plusieurs lignes' do
          expect(subject[:adresse]).to eq("DIRECTION INTERMINISTERIELLE DU NUMERIQUE\r\nJEAN MARIE DURAND\r\nZAE SAINT GUENAULT\r\n51 BIS RUE DE LA PAIX\r\nCS 72809\r\n75256 PARIX CEDEX 12\r\nFRANCE")
        end
      end

      context 'Détails adresse' do
        it 'L’entreprise contient bien un numero_voie' do
          expect(subject[:numero_voie]).to eq('22')
        end

        it 'L’entreprise contient bien un type_voie' do
          expect(subject[:type_voie]).to eq('RUE')
        end

        it 'L’entreprise contient bien un nom_voie' do
          expect(subject[:nom_voie]).to eq('DE LA PAIX')
        end

        it 'L’entreprise contient bien un complement_adresse' do
          expect(subject[:complement_adresse]).to eq('ZAE SAINT GUENAULT')
        end

        it 'L’entreprise contient bien un code_postal' do
          expect(subject[:code_postal]).to eq('75016')
        end

        it 'L’entreprise contient bien une localite' do
          expect(subject[:localite]).to eq('PARIS 12')
        end

        it 'L’entreprise ne contient pas de nom de pays' do
          expect(subject[:nom_pays]).to be_nil
        end

        it 'L’entreprise contient bien un code_insee_localite' do
          expect(subject[:code_insee_localite]).to eq('75112')
        end
      end

      context 'Détails adresse étranger' do
        let(:fixture) { 'spec/fixtures/files/api_entreprise/etablissements-uk.json' }

        it 'L’entreprise contient bien une localite' do
          expect(subject[:localite]).to eq('LONDRES')
        end

        it 'L’entreprise contient bien un nom de pays' do
          expect(subject[:nom_pays]).to eq('ROYAUME-UNI')
        end
      end
    end

    context 'Attributs Etablissements pour etablissement non siege' do
      let(:siret) { '17310120500719' }
      let(:fixture) { 'spec/fixtures/files/api_entreprise/etablissements-non-siege.json' }
      it 'L’entreprise contient bien un siret' do
        expect(subject[:siret]).to eq(siret)
      end

      it 'L’etablissement contient bien un siege_social à false' do
        expect(subject[:siege_social]).to eq(false)
      end

      it 'L’etablissement contient bien une enseigne' do
        expect(subject[:enseigne]).to eq("SERVICE PENITENTIAIRE D'INSERTION ET DE PROBATION, DE LA HAUTE-GARONNE")
      end
    end
  end

  context 'SIRET valide avec infos non diffusables' do
    let(:siret) { '41816609600051' }
    subject { described_class.new(siret, procedure_id).to_params }

    before do
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v3\/insee\/sirene\/etablissements\/#{siret}/)
        .to_return(body: File.read('spec/fixtures/files/api_entreprise/etablissements_private.json', status: 200))
    end

    it 'L’entreprise contient bien un diffusable_commercialement qui vaut false' do
      expect(subject[:diffusable_commercialement]).to eq(false)
    end
  end

  context 'when siret is not found' do
    let(:bad_siret) { 11_111_111_111_111 }
    subject { described_class.new(bad_siret, procedure_id).to_params }

    before do
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v3\/insee\/sirene\/etablissements\/#{bad_siret}/)
        .to_return(body: 'Fake body', status: 404)
    end

    it { expect(subject).to eq({}) }
  end
end
