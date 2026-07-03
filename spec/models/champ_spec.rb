# frozen_string_literal: true

describe Champ do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :text, libelle: 'Nom' }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:type_de_champ) { dossier.revision.types_de_champ_public.first }
  let(:champ_data) { dossier.champ_data.first }
  let(:champ) { Champ.new(dossier:, type_de_champ:, data: champ_data) }

  describe 'identity' do
    it 'derives identity from the type de champ' do
      expect(champ.stable_id).to eq(type_de_champ.stable_id)
      expect(champ.id).to eq(type_de_champ.public_id(nil))
      expect(champ.to_param).to eq(champ.id)
      expect(champ.libelle).to eq('Nom')
      expect(champ.type_champ).to eq('text')
      expect(champ.public?).to be_truthy
    end

    it 'is persisted when a consistent champ data exists' do
      expect(champ.persisted?).to be_truthy
      expect(champ.champ_data_id).to eq(champ_data.id)
    end

    context 'without champ data' do
      let(:champ) { Champ.new(dossier:, type_de_champ:) }

      it 'behaves like a blank unsaved champ' do
        expect(champ.persisted?).to be_falsey
        expect(champ.id).to eq(type_de_champ.public_id(nil))
        expect(champ.champ_data_id).to be_nil
        expect(champ.value).to be_nil
        expect(champ.value_json).to be_nil
        expect(champ.external_id).to be_nil
        expect(champ.updated_at).to eq(dossier.created_at)
        expect(champ.stream).to eq(dossier.stream)
        expect(champ.piece_justificative_file.attached?).to be_falsey
        expect(champ.geo_areas).to be_empty
      end
    end

    context 'with wrong-type champ data' do
      before { champ_data.update_columns(type: 'Champs::EmailChamp', value: 'carried', value_json: { 'k' => 'v' }, external_id: 'x') }

      it 'carries the raw value but hides shaped columns' do
        expect(champ.persisted?).to be_falsey
        expect(champ.value).to eq('carried')
        expect(champ.value_json).to be_nil
        expect(champ.data).to be_nil
        expect(champ.external_id).to be_nil
        expect(champ.external_state).to be_nil
      end
    end
  end

  describe 'writers and persistence facade' do
    it 'buffers writes in memory and copies them to the champ data on save' do
      champ.value = 'hello'
      expect(champ.value_changed?).to be_truthy
      expect(champ_data.value).to be_nil

      expect(champ.writable!.save).to be_truthy
      expect(champ.value_changed?).to be_falsey
      expect(champ_data.reload.value).to eq('hello')
    end

    it 'supports assign_attributes and update' do
      expect(champ.writable!.update(value: 'via update')).to be_truthy
      expect(champ_data.reload.value).to eq('via update')
    end

    it 'prepare_for_update! attaches the upserted champ data as writable' do
      projected = dossier.project_champ(type_de_champ)
      expect(projected.prepared_for_update?).to be_falsey

      projected.prepare_for_update!('someone@exemple.fr')
      expect(projected.prepared_for_update?).to be_truthy
      expect(projected.updated_by).to eq('someone@exemple.fr')
      expect(projected.update(value: 'prepared')).to be_truthy
      expect(projected.champ_data.reload.value).to eq('prepared')
    end

    it 'save raises without a writable champ data' do
      champ.value = 'x'
      expect { champ.save }.to raise_error(Champ::NoDataError)
    end

    context 'without champ data' do
      let(:champ) { Champ.new(dossier:, type_de_champ:) }

      it 'keeps writes in memory' do
        champ.value = 'x'
        champ.external_id = 'y'
        expect(champ.value).to eq('x')
        expect(champ.external_id).to eq('y')
        expect(champ.changed?).to be_truthy
      end

      it 'save raises' do
        expect { champ.save }.to raise_error(Champ::NoDataError)
      end

      it 'association writes raise' do
        expect { champ.etablissement = build(:etablissement) }.to raise_error(Champ::NoDataError)
      end
    end
  end

  describe 'validations' do
    it 'responds to validate with a context, without a writable champ data' do
      expect(champ.validate(:champ_public_value)).to be_truthy
      expect(champ.errors).to be_empty
    end

    it 'runs save callbacks around save' do
      expect(champ.writable!.save).to be_truthy
    end
  end

  describe 'visibility' do
    it 'is visible without condition' do
      expect(champ.visible?).to be_truthy
    end
  end

  describe Champ::JsonStore do
    let(:champ_class) do
      Class.new(Champ) do
        store_accessor :value_json, :city_name, :postal_code
      end
    end
    let(:champ) { champ_class.new(dossier:, type_de_champ:, data: champ_data) }

    it 'reads and writes keys on the in-memory jsonb copy' do
      expect(champ.city_name).to be_nil

      champ.city_name = 'Grenoble'
      champ.postal_code = '38000'

      expect(champ.city_name).to eq('Grenoble')
      expect(champ.value_json_changed?).to be_truthy
      expect(champ.city_name_changed?).to be_truthy
      expect(champ.postal_code_was).to be_nil
      expect(champ_data.value_json).to be_nil

      expect(champ.writable!.save).to be_truthy
      expect(champ_data.reload.value_json).to eq('city_name' => 'Grenoble', 'postal_code' => '38000')
    end

    it 'the jsonb copy is frozen: in-place mutation fails fast' do
      champ.city_name = 'Grenoble'
      expect { champ.value_json['city_name'] = 'Lyon' }.to raise_error(FrozenError)
    end

    context 'without champ data' do
      let(:champ) { champ_class.new(dossier:, type_de_champ:) }

      it 'reads nil and writes in memory' do
        expect(champ.city_name).to be_nil
        expect(champ.city_name_changed?).to be_falsey

        champ.city_name = 'x'
        expect(champ.city_name).to eq('x')
        expect(champ.city_name_changed?).to be_truthy
      end
    end
  end

  describe '#blank?' do
    it 'delegates blankness to the type de champ' do
      expect(champ.blank?).to be_truthy
      champ.writable!.update(value: 'filled')
      expect(champ.blank?).to be_falsey
    end
  end
end
