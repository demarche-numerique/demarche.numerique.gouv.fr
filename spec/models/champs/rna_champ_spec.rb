# frozen_string_literal: true

describe Champs::RNAChamp do
  let(:public_type_de_champs) { [{ type: :rna }] }
  let(:procedure) { create(:procedure, public_type_de_champs:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.root_champs_public.first.tap { _1.update(value:) } }
  let(:value) { "W182736273" }

  def with_external_id(external_id)
    champ.tap do
      _1.external_id = external_id
    end
  end

  describe '#valid?' do
    it do
      expect(with_external_id(nil).validate(:champ_value)).to be_truthy
      expect(with_external_id("2736251627").validate(:champ_value)).to be_falsey
      expect(with_external_id("A172736283").validate(:champ_value)).to be_falsey
      expect(with_external_id("W1827362718").validate(:champ_value)).to be_falsey
      expect(with_external_id("W182736273").validate(:champ_value)).to be_truthy
    end

    it 'when invalid format, it contains only error message for invalid format' do
      champ = with_external_id("W1827362")
      champ.validate(:champ_value)
      expect(champ.errors.full_messages.join).to match(/doit commencer par un W majuscule suivi de 9 chiffres ou lettres. Exemple : W503726238/)
    end

    it 'when valid format, but no data, it contains only error message for not found' do
      champ = with_external_id("W182736273")
      error = ExternalDataException.new(error: 'Not retryable', code: 404)
      champ.update_columns(external_state: 'external_error', fetch_external_data_exceptions: [error])
      champ.validate(:champ_value)
      expect(champ.errors.full_messages).to eq(["Le champ « Numéro RNA » Résultat introuvable. Vérifiez vos informations."])
    end
  end

  describe '#external_id=' do
    let(:value) { nil }

    it 'writes the rna as the value' do
      expect(with_external_id("W182736273").value).to eq("W182736273")
    end
  end

  describe '#fetch_external_data' do
    include Dry::Monads[:result]

    let(:adapter) { instance_double(APIEntreprise::RNAAdapter, to_params:) }

    subject { with_external_id("W182736273").send(:fetch_external_data) }

    before do
      allow(APIEntreprise::RNAAdapter).to receive(:new).and_return(adapter)
    end

    context 'when the association is found' do
      let(:to_params) { Success({ "association_titre" => "Super asso", "adresse" => {} }) }

      it 'returns a Success with data and value_json' do
        expect(subject).to be_success
        expect(subject.value!).to include(data: { "association_titre" => "Super asso", "adresse" => {} })
      end
    end

    context 'when the association is not found (empty hash)' do
      let(:to_params) { Success({}) }

      it 'returns a non-retryable 404 Failure' do
        expect(subject).to be_failure
        expect(subject.failure).to include(retryable: false, code: 404)
      end
    end

    context 'when API Entreprise is down' do
      let(:to_params) { Failure(type: :service_unavailable, code: 503, retryable: true, raw_response: nil) }

      it 'degrades instead of failing' do
        expect(subject).to be_failure
        expect(subject.failure).to include(degraded: true, code: 503)
      end
    end

    context 'when API Entreprise refuses our token' do
      let(:to_params) { Failure(type: :unauthorized, code: 401, retryable: false, raw_response: nil) }

      before { allow(Sentry).to receive(:capture_message) }

      it 'degrades too: the usager has no hold on our credentials' do
        expect(subject.failure).to include(degraded: true, code: 401)
      end
    end

    context 'when the association does not exist' do
      let(:to_params) { Failure(type: :unprocessable, code: 422, retryable: false, raw_response: nil) }

      it 'stays a plain error: only the usager can fix it' do
        expect(subject.failure).to include(retryable: false, code: 422)
        expect(subject.failure).not_to have_key(:degraded)
      end
    end

    context 'when the payload cannot be read' do
      let(:to_params) { Success({}) }

      before do
        allow(adapter).to receive(:to_params).and_raise(NoMethodError.new("undefined method '[]' for nil"))
        allow(Sentry).to receive(:capture_exception)
      end

      it 'degrades rather than stranding the champ in fetching' do
        expect(subject.failure).to include(degraded: true, code: 200)
      end
    end

    context 'when the address of the association cannot be read' do
      let(:to_params) { Success({ "association_titre" => "Super asso", "adresse" => nil }) }

      before { allow(Sentry).to receive(:capture_exception) }

      it 'degrades as well' do
        expect(subject.failure).to include(degraded: true, code: 200)
      end
    end

    context 'when something else than the payload fails' do
      let(:to_params) { Success({ "association_titre" => "Super asso", "adresse" => {} }) }

      before do
        allow(champ.procedure).to receive(:forget_api_entreprise_token_rejection!).and_raise(ActiveRecord::StatementInvalid)
      end

      it 'lets the error through instead of passing it off as an API fault' do
        expect { subject }.to raise_error(ActiveRecord::StatementInvalid)
      end
    end

    context 'when the token cannot work at all' do
      let(:procedure) { create(:procedure, api_entreprise_token: nil, public_type_de_champs:) }
      let(:to_params) { Success({}) }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('API_ENTREPRISE_KEY').and_return(nil)
        allow(Sentry).to receive(:capture_message)
      end

      it 'does not even call the API' do
        subject
        expect(APIEntreprise::RNAAdapter).not_to have_received(:new)
      end

      it 'degrades with the reason operations needs' do
        expect(subject.failure).to include(degraded: true, code: 401)
      end
    end
  end

  describe "default export" do
    context "with association title" do
      before do
        champ.update(value_json: { title: "Super asso" })
      end

      it { expect(legacy_export_cells(champ).first.second).to eq("W182736273 (Super asso)") }
    end

    context "no association title" do
      it { expect(legacy_export_cells(champ).first.second).to eq("W182736273") }
    end
  end
end
