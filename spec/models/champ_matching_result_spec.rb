# frozen_string_literal: true

describe ChampMatchingResult do
  empty_seeds TypeDeChampMatch, ProcedureUserOverlap

  let(:left) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Votre adresse' }, { type: :text, libelle: 'Votre téléphone' }]) }
  let(:right) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Adresse du domicile' }, { type: :text, libelle: 'Téléphone mobile' }]) }

  def stable_ids(procedure) = procedure.published_revision.public_root_type_de_champs.map(&:stable_id)

  def match!(index, matching_users_count)
    TypeDeChampMatch.create!(left_procedure_id: left.id, left_stable_id: stable_ids(left)[index],
                             right_procedure_id: right.id, right_stable_id: stable_ids(right)[index],
                             matching_users_count:, common_users_count: 80)
  end

  before do
    ProcedureUserOverlap.create!(left_procedure_id: left.id, right_procedure_id: right.id,
                                 common_users_count: 80)
  end

  describe '.find' do
    it 'reads the match from the procedure its parameter names' do
      match = match!(0, 78)
      row = described_class.sections.find { it.procedure_id == right.id }.partners.sole.couples.sole

      expect(row.to_param).to eq("#{match.id}-#{right.id}")
      expect(described_class.find(row.to_param)).to have_attributes(procedure_id: right.id, libelle: 'Adresse du domicile', partner_libelle: 'Votre adresse', namespace: :text)
      expect(described_class.find("#{match.id}-#{left.id}")).to have_attributes(procedure_id: left.id, libelle: 'Votre adresse')
    end
  end

  describe '#observations' do
    let(:left) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Votre adresse' }]) }
    let(:right) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Adresse du domicile' }]) }
    let(:match) { TypeDeChampMatch.sole }

    def depose(procedure, user, value)
      create(:dossier, :en_construction, procedure:, user:).champ_data.find { !it.private? }.update_column(:value, value)
    end

    def observe(from) = described_class.find("#{match.id}-#{from.id}").observations

    before do
      stub_const('ChampMatchingConcern::USERS_FLOOR', 1)

      {
        create(:user) => ['12 rue du Pont', '12, Rue du PONT'],
        create(:user) => ['3 cours Lafayette', '9 avenue des Ternes'],
        create(:user) => ['5 place Bellecour', nil],
      }.each do |user, (left_value, right_value)|
        depose(left, user, left_value)
        depose(right, user, right_value)
      end

      ProcedureUserOverlap.refresh_within([left.id, right.id])
      ProcedureUserOverlap.find_each(&:refresh_champ_matches!)
    end

    it 'replays exactly what the matching counted' do
      observations = observe(left)

      expect(observations.count(&:answered?)).to eq(match.common_users_count)
      expect(observations.count(&:matching?)).to eq(match.matching_users_count)
      expect(observations.count { !it.answered? }).to eq(1)
    end

    it 'keeps what the usager typed beside what was compared' do
      concordant = observe(left).find(&:matching?)

      expect(concordant.values.map { [it.raw, it.comparable] }).to eq([['12 rue du Pont', '12 rue du pont']])
      expect(concordant.partner_values.map { [it.raw, it.comparable] }).to eq([['12, Rue du PONT', '12 rue du pont']])
      expect(concordant.shared_comparables).to eq(['12 rue du pont'])
    end

    it 'points each value at the dossier it was typed in' do
      concordant = observe(left).find(&:matching?)

      expect(Dossier.find(concordant.values.sole.dossier_id).procedure).to eq(left)
      expect(Dossier.find(concordant.partner_values.sole.dossier_id).procedure).to eq(right)
    end

    it 'puts the procedure it is read from on the left' do
      expect(observe(right).find(&:matching?).values.first.raw).to eq('12, Rue du PONT')
    end
  end

  describe '.sections' do
    it 'groups the matches under each of their two procedures, best score first' do
      match!(1, 40)
      match!(0, 78)

      sections = described_class.sections

      expect(sections.map(&:procedure_id)).to contain_exactly(left.id, right.id)

      section = sections.find { it.procedure_id == left.id }
      partner = section.partners.sole

      expect(partner).to have_attributes(procedure_id: right.id, libelle: right.libelle, common_users_count: 80)
      expect(partner.couples.map(&:libelle)).to eq(['Votre adresse', 'Votre téléphone'])
      expect(partner.couples.map(&:confirmed)).to eq([true, false])
      expect(section).to have_attributes(libelle: left.libelle, couples_count: 2, confirmed_count: 1)
    end

    it 'turns the couple around under the partner procedure' do
      match!(0, 78)

      couple = described_class.sections.find { it.procedure_id == right.id }.partners.sole.couples.sole

      expect(couple).to have_attributes(
        procedure_id: right.id, stable_id: stable_ids(right).first, libelle: 'Adresse du domicile',
        partner_procedure_id: left.id, partner_stable_id: stable_ids(left).first, partner_libelle: 'Votre adresse',
        matching_users_count: 78, common_users_count: 80, confirmed: true
      )
      expect(couple.score).to be_within(0.01).of(0.91)
    end
  end
end
