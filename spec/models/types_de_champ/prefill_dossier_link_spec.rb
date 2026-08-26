# frozen_string_literal: true

RSpec.describe TypesDeChamp::PrefillDossierLink do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :dossier_link }]) }
  let(:dossier) { create(:dossier, :brouillon, procedure:) }
  let(:type_de_champ) { procedure.active_revision.public_root_type_de_champs.first }
  let(:champ) { dossier.champ_data.first }

  describe 'ancestors' do
    subject { described_class.build(type_de_champ, procedure.active_revision) }

    it { is_expected.to be_kind_of(TypesDeChamp::Prefill) }
  end

  describe '#to_assignable_attributes' do
    subject(:to_assignable_attributes) { described_class.build(type_de_champ, procedure.active_revision).to_assignable_attributes(champ, value) }

    context 'when the value is the id of a dossier en construction' do
      let(:value) { create(:dossier, :en_construction).id }

      it { is_expected.to eq({ value: value.to_s }) }
    end

    context 'when the value is a string representing the id of a dossier en construction' do
      let(:value) { create(:dossier, :en_construction).id.to_s }

      it { is_expected.to eq({ value: value.to_s }) }
    end

    context 'when the value is the id of a deleted dossier' do
      let(:value) { create(:deleted_dossier).dossier_id }

      it { is_expected.to eq({ value: value.to_s }) }
    end

    context 'when the value is not an integer' do
      let(:value) { 'totoro' }

      it { is_expected.to be_nil }
    end

    context 'when the value has a leading zero' do
      let(:dossier_en_construction) { create(:dossier, :en_construction) }
      let(:value) { "0#{dossier_en_construction.id}" }

      it 'parses it as decimal (not octal) and assigns the normalized id' do
        expect(to_assignable_attributes).to eq({ value: dossier_en_construction.id.to_s })
      end
    end

    context 'when the value is the id of a dossier that does not exist' do
      let(:value) { -1 }

      it { is_expected.to be_nil }
    end

    context 'when the value is the id of a brouillon dossier' do
      let(:value) { create(:dossier).id }

      it { is_expected.to be_nil }
    end

    context 'when the type de champ restricts the allowed procedures' do
      let(:allowed_procedure) { create(:procedure) }
      let(:other_procedure) { create(:procedure) }

      before do
        type_de_champ.update!(options: type_de_champ.options.merge(
          'procedures_limit' => '1',
          'dossier_link_procedure_ids' => [allowed_procedure.id]
        ))
      end

      context 'when the dossier belongs to an allowed procedure and to the current user' do
        let(:value) { create(:dossier, :en_construction, procedure: allowed_procedure, user: dossier.user).id }

        it { is_expected.to eq({ value: value.to_s }) }
      end

      context 'when the dossier does not belong to an allowed procedure' do
        let(:value) { create(:dossier, :en_construction, procedure: other_procedure, user: dossier.user).id }

        it { is_expected.to be_nil }
      end

      context 'when the dossier belongs to another user' do
        let(:value) { create(:dossier, :en_construction, procedure: allowed_procedure).id }

        it { is_expected.to be_nil }
      end

      context 'when the deleted dossier belongs to an allowed procedure and to the current user' do
        let(:value) { create(:deleted_dossier, procedure: allowed_procedure, user_id: dossier.user.id).dossier_id }

        it { is_expected.to eq({ value: value.to_s }) }
      end
    end
  end
end
