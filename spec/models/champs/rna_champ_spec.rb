# frozen_string_literal: true

describe Champs::RNAChamp do
  let(:types_de_champ_public) { [{ type: :rna }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.project_champs_public.first.tap { _1.writable!.update(value:) } }
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

  describe '#fetch_external_data' do
    include Dry::Monads[:result]

    let(:adapter) { instance_double(APIEntreprise::RNAAdapter, to_params:) }

    subject { with_external_id("W182736273").send(:fetch_external_data) }

    before do
      allow(APIEntreprise::RNAAdapter).to receive(:new).and_return(adapter)
    end

    context 'when the association is found' do
      let(:to_params) { Success({ "association_titre" => "Super asso", "adresse" => {} }) }

      it 'returns a Success with data, value_json and value' do
        expect(subject).to be_success
        expect(subject.value!).to include(data: { "association_titre" => "Super asso", "adresse" => {} }, value: "W182736273")
      end
    end

    context 'when the association is not found (empty hash)' do
      let(:to_params) { Success({}) }

      it 'returns a non-retryable 404 Failure' do
        expect(subject).to be_failure
        expect(subject.failure).to include(retryable: false, code: 404)
      end
    end

    context 'when the API returns a retryable failure' do
      let(:to_params) { Failure(type: :network_error, code: 503, retryable: true, raw_response: nil) }

      it 'propagates a retryable Failure' do
        expect(subject).to be_failure
        expect(subject.failure).to include(retryable: true, code: 503)
      end
    end
  end

  describe "#export" do
    context "with association title" do
      before do
        champ.update(data: { association_titre: "Super asso" })
      end

      it { expect(champ.type_de_champ.champ_value_for_export(champ)).to eq("W182736273 (Super asso)") }
    end

    context "no association title" do
      it { expect(champ.type_de_champ.champ_value_for_export(champ)).to eq("W182736273") }
    end
  end
end
