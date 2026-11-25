# frozen_string_literal: true

RSpec.describe Mutations::DemarcheBrouillonMutation, type: :graphql do
  let(:admin) { administrateurs.default }
  let(:procedure) do
    create(:procedure, administrateurs: [admin], public_type_de_champs: [
      { type: :integer_number, libelle: 'age' },
      { type: :repetition, libelle: 'enfants', children: [{ libelle: 'prénom' }] },
      { type: :yes_no, libelle: 'boursier' },
    ])
  end
  let(:context) { { administrateur_id: admin.id, procedure_ids: admin.procedure_ids, write_access: true, remote_ip: '192.168.1.23' } }
  let(:input) { {} }

  subject { API::V2::Schema.execute(query, variables: { input: { demarche: { number: procedure.id }, **input } }, context:) }

  let(:data) { subject['data'].deep_symbolize_keys.values.first }

  def tdc(libelle) = procedure.draft_revision.reload.type_de_champs.find { it.libelle == libelle }
  def id(libelle) = tdc(libelle).to_typed_id
  def public_libelles = procedure.draft_revision.reload.public_root_type_de_champs.map(&:libelle)

  before { procedure }

  describe 'demarcheAjouterChamp' do
    let(:query) { mutation('demarcheAjouterChamp', 'DemarcheAjouterChampInput') }
    let(:input) { { type: 'drop_down_list', label: 'statut', required: true, apresId: id('age'), options: { drop_down_options: ['salarié', 'étudiant'] } } }

    it 'adds the champ to the draft' do
      expect(data[:errors]).to be_nil
      expect(data[:champDescriptor]).to eq(id: id('statut'), label: 'statut', required: true, __typename: 'DropDownListChampDescriptor')
      expect(public_libelles).to eq(['age', 'statut', 'enfants', 'boursier'])
      expect(tdc('statut').drop_down_options).to eq(['salarié', 'étudiant'])
    end

    context 'in a repetition' do
      let(:input) { { type: 'date', label: 'naissance', parentId: id('enfants') } }

      it { expect(data[:errors]).to be_nil }
    end

    context 'with options of another type' do
      let(:input) { { type: 'text', label: 'nom', options: { character_limit: 10 } } }

      it 'is refused, with the reason' do
        expect(data[:champDescriptor]).to be_nil
        expect(data[:errors]).to eq([{ message: "Options inconnues pour le type « text » : character_limit. Options acceptées : aucune." }])
      end
    end

    context 'with an invalid id' do
      let(:input) { { type: 'text', label: 'nom', apresId: 'not-an-id' } }

      it { expect(data[:errors]).to eq([{ message: "L'identifiant de champ \"not-an-id\" est invalide." }]) }
    end

    context 'on a démarche of another administrateur' do
      let(:context) { super().merge(procedure_ids: []) }

      it 'is refused' do
        expect(data[:errors]).to eq([{ message: "La démarche \"#{procedure.id}\" n'existe pas ou vous n'avez pas le droit de la modifier." }])
        expect(public_libelles).to eq(['age', 'enfants', 'boursier'])
      end
    end

    context 'with a read only token' do
      let(:context) { super().merge(write_access: false) }

      it 'is refused' do
        expect(data[:errors]).to eq([{ message: 'Le jeton utilisé est configuré seulement en lecture' }])
        expect(public_libelles).to eq(['age', 'enfants', 'boursier'])
      end
    end
  end

  describe 'demarcheModifierChamp' do
    let(:query) { mutation('demarcheModifierChamp', 'DemarcheModifierChampInput') }
    let(:input) { { champId: id('age'), label: 'âge', type: 'decimal_number', options: { positive_number: true } } }

    it 'updates the champ, its type and its options' do
      champ_id = id('age')

      expect(data[:errors]).to be_nil
      expect(data[:champDescriptor]).to include(id: champ_id, label: 'âge', __typename: 'DecimalNumberChampDescriptor')
      expect(tdc('âge')).to be_positive_number
    end
  end

  describe 'demarcheDeplacerChamp' do
    let(:query) { mutation('demarcheDeplacerChamp', 'DemarcheDeplacerChampInput') }
    let(:input) { { champId: id('age'), apresId: id('boursier') } }

    it 'moves the champ' do
      expect(data[:errors]).to be_nil
      expect(public_libelles).to eq(['enfants', 'boursier', 'age'])
    end

    context 'without a champ to place it after' do
      let(:input) { { champId: id('boursier') } }

      it 'moves it first' do
        expect(data[:errors]).to be_nil
        expect(public_libelles).to eq(['boursier', 'age', 'enfants'])
      end
    end
  end

  describe 'demarcheSupprimerChamp' do
    let(:query) { mutation('demarcheSupprimerChamp', 'DemarcheSupprimerChampInput') }
    let(:input) { { champId: id('enfants') } }

    it 'removes the champ' do
      expect(data).to eq(champDescriptor: nil, errors: nil)
      expect(public_libelles).to eq(['age', 'boursier'])
    end
  end

  describe 'demarcheModifierChampCondition' do
    let(:query) { mutation('demarcheModifierChampCondition', 'DemarcheModifierChampConditionInput') }
    let(:input) { { champId: id('boursier'), combinateur: 'ou', termes: [{ champId: id('age'), operateur: 'less_than', valeur: '26' }, { champId: id('age'), operateur: 'greater_than', valeur: '60' }] } }

    it 'sets the condition' do
      age = Logic::ChampValue.new(tdc('age').stable_id)

      expect(data[:errors]).to be_nil
      expect(tdc('boursier').condition).to eq(Logic::Or.new([Logic::LessThan.new(age, Logic::Constant.new(26)), Logic::GreaterThan.new(age, Logic::Constant.new(60))]))
    end

    context 'on a champ placed after' do
      let(:input) { { champId: id('age'), termes: [{ champId: id('boursier'), operateur: 'eq', valeur: 'true' }] } }

      it 'is refused' do
        expect(data[:errors].first[:message]).to include('doit être placée avant « age »')
        expect(tdc('age').condition).to be_nil
      end
    end

    context 'without a term' do
      let(:input) { { champId: id('boursier'), termes: [] } }

      before { tdc('boursier').update!(condition: Logic::Eq.new(Logic::ChampValue.new(tdc('age').stable_id), Logic::Constant.new(18))) }

      it 'removes the condition' do
        expect(data[:errors]).to be_nil
        expect(tdc('boursier').condition).to be_nil
      end
    end
  end

  def mutation(name, input_type)
    <<~GRAPHQL
      mutation($input: #{input_type}!) {
        #{name}(input: $input) {
          champDescriptor { id label required __typename }
          errors { message }
        }
      }
    GRAPHQL
  end
end
