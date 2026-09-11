# frozen_string_literal: true

describe 'Dossier#can_submit_modifications?' do
  include Logic

  let(:procedure) do
    create(:procedure, :published, public_type_de_champs: [
      { type: :checkbox, libelle: 'certifie', stable_id: 1 },
      { type: :text, libelle: 'texte', stable_id: 2 },
    ])
  end
  let(:dossier) { create(:dossier, procedure:) }
  let(:checkbox) { dossier.champ_data.find { it.stable_id == 1 } }
  let(:texte) { dossier.champ_data.find { it.stable_id == 2 } }

  before do
    procedure.published_revision.update!(
      ineligibilite_enabled: true,
      ineligibilite_message: 'non éligible',
      ineligibilite_rules: ds_eq(champ_value(1), constant(false))
    )
  end

  context 'when the dossier is untouched, its champ rows existing since creation' do
    it 'stays modifiable, but the deposit of the brouillon stays closed' do
      expect(dossier.reload.can_submit_modifications?).to be true
      expect(dossier.can_passer_en_construction?).to be false
    end
  end

  context 'when the usager filled another champ' do
    before { texte.update!(value: 'coucou') && texte.update_timestamps }

    it 'stays modifiable' do
      expect(dossier.reload.can_submit_modifications?).to be true
    end
  end

  context 'when the usager checked then unchecked the box, leaving only a write trace' do
    before do
      checkbox.update!(value: 'true')
      checkbox.update_timestamps
      checkbox.update!(value: 'false')
    end

    it 'is closed' do
      expect(dossier.reload.can_submit_modifications?).to be false
      expect(dossier.can_passer_en_construction?).to be false
    end
  end

  context 'when the box was prefilled to the ineligible value' do
    before { checkbox.update!(value: 'false', prefilled: true) }

    it 'is closed, prefilled data being real data' do
      expect(dossier.reload.can_submit_modifications?).to be false
    end
  end

  context 'when the usager checked the box' do
    before do
      checkbox.update!(value: 'true')
      checkbox.update_timestamps
    end

    it 'stays modifiable and opens the deposit' do
      expect(dossier.reload.can_submit_modifications?).to be true
      expect(dossier.can_passer_en_construction?).to be true
    end
  end

  context 'when the dossier has already been submitted, its checkbox never touched' do
    let(:dossier) { create(:dossier, :en_construction, procedure:) }

    it 'leaves the usager and the instructeur free to modify it' do
      expect(dossier.reload.can_submit_modifications?).to be true
    end
  end

  context 'with a drop_down_list on « Autre », blank? yet answered, in the undated user buffer' do
    let(:procedure) do
      create(:procedure, :published, public_type_de_champs: [
        { type: :drop_down_list, stable_id: 1, drop_down_options: ['a', 'b'], drop_down_other: true },
      ])
    end
    let(:dossier) { create(:dossier, :en_construction, procedure:) }

    before do
      procedure.published_revision.update!(ineligibilite_rules: ds_eq(champ_value(1), constant(Champs::DropDownListChamp::OTHER)))

      dossier.with_update_stream(dossier.user) do
        champ = dossier.champ_for_update(dossier.revision.type_de_champs.first, updated_by: dossier.user.email)
        champ.assign_attributes(value: Champs::DropDownListChamp::OTHER)
        Dossier.no_touching { champ.save }
        champ.update_timestamps
      end
      dossier.reload
    end

    it 'is closed' do
      dossier.with_update_stream(dossier.user) do
        expect(dossier.can_submit_modifications?).to be false
      end
    end
  end

  context 'with a yes_no rule instead, which yields no value until answered' do
    let(:procedure) do
      create(:procedure, :published, public_type_de_champs: [{ type: :yes_no, libelle: 'majeur', stable_id: 1 }])
    end

    before do
      procedure.published_revision.update!(ineligibilite_rules: ds_eq(champ_value(1), constant(true)))
    end

    context 'when the dossier is untouched' do
      it 'stays modifiable and leaves the deposit open' do
        expect(dossier.reload.can_submit_modifications?).to be true
        expect(dossier.can_passer_en_construction?).to be true
      end
    end

    context 'when the usager answered Oui' do
      before { dossier.champ_data.find { it.stable_id == 1 }.update!(value: 'true') }

      it 'is closed and blocks the deposit' do
        expect(dossier.reload.can_submit_modifications?).to be false
        expect(dossier.can_passer_en_construction?).to be false
      end
    end
  end

  context 'when ineligibilite is disabled' do
    before { procedure.published_revision.update!(ineligibilite_enabled: false) }

    it { expect(dossier.reload.can_submit_modifications?).to be true }
  end
end
