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
