# frozen_string_literal: true

require 'rails_helper'

describe ChampMatchingConcern do
  empty_seeds ProcedureUserOverlap

  let(:left) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Votre adresse' }]) }
  let(:right) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Adresse du domicile' }]) }
  let(:perimeter) { [left.id, right.id] }

  # Le plancher est abaissé partout : ces scénarios tiennent en deux ou trois
  # usagers, là où la production en demande cinquante.
  before { stub_const('ChampMatchingConcern::USERS_FLOOR', 1) }

  def refresh
    ProcedureUserOverlap.refresh_within(perimeter)
    ProcedureUserOverlap.find_each(&:refresh_champ_matches!)

    TypeDeChampMatch.all
  end

  def depose(procedure, user, value, depose_at: nil, **attributes)
    dossier = create(:dossier, :en_construction, procedure:, user:, depose_at:)
    dossier.update_columns(attributes) if attributes.any?
    dossier.champ_data.find { !it.private? }.update_column(:value, value)
    dossier
  end

  context 'when two usagers each repeated their own value across both procedures' do
    before do
      ['12 rue du Pont', '3 cours Lafayette'].each do |value|
        user = create(:user)
        depose(left, user, value)
        depose(right, user, value)
      end
    end

    it 'links the two champs, counting each usager once' do
      expect(refresh.count).to eq(1)
      expect(refresh.first).to have_attributes(matching_users_count: 2, common_users_count: 2)
    end

    it 'rewrites the same thing when run again' do
      refresh
      expect { refresh }.not_to change(TypeDeChampMatch, :count)
      expect(refresh.first.matching_users_count).to eq(2)
    end
  end

  it 'counts only the usager who repeated, out of the two who could have' do
    one = create(:user)
    depose(left, one, '12 rue du Pont')
    depose(right, one, '12 rue du Pont')

    two = create(:user)
    depose(left, two, '3 cours Lafayette')
    depose(right, two, '9 avenue des Ternes')

    expect(refresh.first).to have_attributes(matching_users_count: 1, common_users_count: 2)
  end

  # Le cas des champs facultatifs : déposer ne veut pas dire répondre. Compter
  # le troisième au dénominateur ferait tomber un rapprochement parfait à 0,67.
  it 'rates the concordance on the usagers who answered both champs' do
    2.times do |index|
      user = create(:user)
      depose(left, user, "#{index} rue du Pont")
      depose(right, user, "#{index} rue du Pont")
    end

    silent = create(:user)
    depose(left, silent, '3 cours Lafayette')
    depose(right, silent, nil)

    expect(refresh.first).to have_attributes(matching_users_count: 2, common_users_count: 2)
  end

  # La déduplication des couples (usager, démarche) est ce qui empêche une
  # démarche de s'apparier avec elle-même.
  it 'counts an usager once however many dossiers they deposited' do
    user = create(:user)
    depose(left, user, '12 rue du Pont')
    depose(left, user, '12 rue du Pont')
    depose(right, user, '12 rue du Pont')

    expect(refresh.count).to eq(1)
    expect(refresh.first).to have_attributes(matching_users_count: 1, common_users_count: 1,
                                             left_procedure_id: perimeter.min,
                                             right_procedure_id: perimeter.max)
  end

  it 'links nothing when a value is shared between usagers but never within one' do
    moving = create(:user)
    depose(left, moving, '12 rue du Pont')
    depose(right, moving, '3 cours Lafayette')

    other = create(:user)
    depose(left, other, '3 cours Lafayette')
    depose(right, other, '9 avenue des Ternes')

    expect(refresh).to be_empty
  end

  context 'with an address champ on both sides' do
    let(:left) { create(:procedure, :published, public_type_de_champs: [{ type: :address }]) }
    let(:right) { create(:procedure, :published, public_type_de_champs: [{ type: :address }]) }

    it 'compares the BAN codes and the street' do
      ban = { 'postal_code' => '75011', 'city_code' => '75056', 'street_address' => '12 rue du Pont' }
      user = create(:user)
      [left, right].each { depose(it, user, nil).champ_data.find { !it.private? }.update_column(:value_json, ban) }

      expect(refresh.first).to have_attributes(matching_users_count: 1, common_users_count: 1)
    end
  end

  describe 'the dossiers it refuses to read' do
    let(:user) { create(:user) }

    before { depose(left, user, '12 rue du Pont') }

    it 'ignores a brouillon, which was never submitted' do
      create(:dossier, procedure: right, user:).champ_data.find { !it.private? }.update_column(:value, '12 rue du Pont')

      expect(refresh).to be_empty
    end

    it 'ignores a dossier filed on behalf of somebody else' do
      depose(right, user, '12 rue du Pont', for_tiers: true)

      expect(refresh).to be_empty
    end

    # Masqué ou expiré ne dit rien des valeurs saisies, donc le dossier reste
    # une preuve.
    it 'still reads a dossier hidden by the administration' do
      depose(right, user, '12 rue du Pont', hidden_by_administration_at: Time.current)

      expect(refresh.first).to have_attributes(matching_users_count: 1, common_users_count: 1)
    end
  end

  # Aucune des deux ne recevra plus de dossier : le rapprochement ne servirait
  # jamais à préremplir quoi que ce soit.
  it 'forms no pair when neither procedure is published any more' do
    user = create(:user)
    depose(left, user, '12 rue du Pont')
    depose(right, user, '12 rue du Pont')
    [left, right].each(&:close!)

    expect(refresh).to be_empty
    expect(ProcedureUserOverlap.count).to eq(0)
  end

  describe 'the floors' do
    before do
      one = create(:user)
      depose(left, one, '12 rue du Pont')
      depose(right, one, '12 rue du Pont')

      two = create(:user)
      depose(left, two, '3 cours Lafayette')
      depose(right, two, '9 avenue des Ternes')
    end

    it 'drops the pair before reading a champ when too few usagers crossed it' do
      stub_const('ChampMatchingConcern::USERS_FLOOR', 3)

      expect(refresh).to be_empty
      expect(ProcedureUserOverlap.count).to eq(0)
    end

    # Deux usagers en commun, un seul qui concorde : la paire passe le
    # plancher, le couple non.
    it 'keeps the pair but writes no couple under the retention floor' do
      stub_const('ChampMatchingConcern::USERS_FLOOR', 2)

      expect(refresh).to be_empty
      expect(ProcedureUserOverlap.count).to eq(1)
    end
  end

  # Seul le plus ancien des trois usagers concorde : capé à deux, on ne regarde
  # que les deux plus récents, et il n'y a plus rien à trouver.
  describe 'the cap on usagers' do
    before do
      oldest = create(:user)
      depose(left, oldest, '12 rue du Pont', depose_at: 3.years.ago)
      depose(right, oldest, '12 rue du Pont', depose_at: 3.years.ago)

      2.times do |index|
        user = create(:user)
        depose(left, user, "#{index} rue du Pont", depose_at: index.days.ago)
        depose(right, user, "#{index} avenue des Ternes", depose_at: index.days.ago)
      end
    end

    it 'examines every usager when the cap covers them all' do
      stub_const('ChampMatchingConcern::MAX_USERS', 3)

      expect(refresh.first).to have_attributes(matching_users_count: 1, common_users_count: 3)
    end

    it 'keeps the most recent usagers when capped' do
      stub_const('ChampMatchingConcern::MAX_USERS', 2)

      expect(refresh).to be_empty
    end
  end

  # Le plafond par usager et par démarche suit la même règle : on garde les
  # dossiers les plus récents, donc la valeur qu'il a saisie en dernier.
  describe 'the cap on dossiers per usager and procedure' do
    before do
      user = create(:user)
      depose(left, user, '9 avenue des Ternes', depose_at: 1.day.ago)
      depose(left, user, '12 rue du Pont', depose_at: 2.years.ago)
      depose(right, user, '12 rue du Pont')
    end

    it 'unions every dossier when the cap covers them all' do
      stub_const('ChampMatchingConcern::MAX_DOSSIERS_PER_USER_AND_PROCEDURE', 2)

      expect(refresh.first).to have_attributes(matching_users_count: 1, common_users_count: 1)
    end

    it 'keeps only the latest dossier of each procedure when capped' do
      stub_const('ChampMatchingConcern::MAX_DOSSIERS_PER_USER_AND_PROCEDURE', 1)

      expect(refresh).to be_empty
    end
  end
end
