# frozen_string_literal: true

RSpec.describe ChampValidateConcern do
  let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:type_de_champ) { dossier.revision.public_root_type_de_champs.first }
  let(:public_id) { type_de_champ.public_id(nil) }
  let(:public_type_de_champs) { [{ type: :email }] }

  def update_champ(value)
    dossier.public_champ_for_update(public_id, updated_by: 'test').update(value:)
  end

  context 'when in revision' do
    context 'valid' do
      before {
        update_champ('test@test.com')
        dossier.validate(:champs_public_value)
      }
      it {
        expect(dossier.champ_data).not_to be_empty
        expect(dossier.errors).to be_empty
      }
    end

    context 'invalid' do
      before {
        update_champ('test')
        dossier.validate(:champs_public_value)
      }
      it {
        expect(dossier.champ_data).not_to be_empty
        expect(dossier.errors).not_to be_empty
      }
    end
  end

  context 'when not in revision' do
    context 'do not validate champs not on current revision' do
      before {
        update_champ('test')
        dossier.revision.revision_type_de_champs.delete_all
        dossier.reload
        dossier.validate(:champs_public_value)
      }
      it {
        expect(dossier.revision.revision_type_de_champs).to be_empty
        expect(dossier.champ_data).not_to be_empty
        expect(dossier.errors).to be_empty
      }
    end

    context 'attachments' do
      let(:public_type_de_champs) { [{ type: :piece_justificative }, { type: :piece_justificative, nature: 'titre_identite' }] }

      before {
        dossier.revision.revision_type_de_champs.delete_all
        dossier.reload
        dossier.validate(:champs_public_value)
      }
      it {
        expect(dossier.revision.revision_type_de_champs).to be_empty
        expect(dossier.champ_data).not_to be_empty
        expect(dossier.errors).to be_empty
      }
    end

    context 'drop_down_list' do
      let(:public_type_de_champs) { [{ type: :drop_down_list }] }

      before {
        dossier.revision.revision_type_de_champs.delete_all
        dossier.reload
        dossier.validate(:champs_public_value)
      }
      it {
        expect(dossier.revision.revision_type_de_champs).to be_empty
        expect(dossier.champ_data).not_to be_empty
        expect(dossier.errors).to be_empty
      }
    end

    context 'external_data which needs validation but is not in revision' do
      let(:public_type_de_champs) { [{ type: :piece_justificative, nature: 'rib' }] }

      before do
        allow_any_instance_of(Champs::PieceJustificativeChamp).to receive(:external_data_needed_for_validation?).and_return(true)

        dossier.champ_data.first.update_column(:external_state, 'waiting_for_job')
        dossier.revision.revision_type_de_champs.delete_all

        dossier.reload
        dossier.validate(:champs_public_value)
      end

      it {
        expect(dossier.champ_data).not_to be_empty
        expect(dossier.errors).to be_empty
      }
    end
  end

  context 'when type changed' do
    context 'do not validate with old champ type' do
      before {
        update_champ('test')
        type_de_champ.becomes!(TypesDeChamp::Text).save
        dossier.reload
        dossier.validate(:champs_public_value)
      }
      it {
        expect(dossier.champ_data.first.last_write_type_champ).to eq('email')
        expect(TypeDeChamp.find(type_de_champ.id)).to be_an_instance_of(TypesDeChamp::Text)
        expect(dossier.champ_data).not_to be_empty
        expect(dossier.errors).to be_empty
      }
    end

    context 'validate the carried over value with the new champ type' do
      let(:public_type_de_champs) { [{ type: :text }] }

      before {
        update_champ('test')
        type_de_champ.becomes!(TypesDeChamp::Email).save
        dossier.reload
        dossier.validate(:champs_public_value)
      }
      it {
        expect(dossier.champ_data.first.last_write_type_champ).to eq('text')
        expect(TypeDeChamp.find(type_de_champ.id)).to be_an_instance_of(TypesDeChamp::Email)
        expect(dossier.champ_data).not_to be_empty
        expect(dossier.errors).not_to be_empty
      }
    end
  end

  context 'when in a row' do
    let(:public_type_de_champs) { [{ type: :repetition, children: [{ type: :email }], mandatory: true }] }
    let(:type_de_champ_in_repetition) { dossier.revision.children_of(type_de_champ).first }
    let(:row_id) { dossier.repetition_row_ids(type_de_champ).first }
    let(:public_id) { type_de_champ_in_repetition.public_id(row_id) }

    context 'valid' do
      before {
        update_champ('test@test.com')
        dossier.validate(:champs_public_value)
      }
      it {
        expect(dossier.champ_data).not_to be_empty
        expect(dossier.errors).to be_empty
      }
    end

    context 'invalid' do
      before {
        update_champ('test')
        dossier.validate(:champs_public_value)
      }
      it {
        expect(dossier.champ_data).not_to be_empty
        expect(dossier.errors).not_to be_empty
      }
    end

    context 'do not validate when in discarded row' do
      before {
        update_champ('test')
        dossier.repetition_remove_row(type_de_champ, row_id, updated_by: 'test')
        dossier.reload
        dossier.validate(:champs_public_value)
      }
      it {
        expect(dossier.champ_data).not_to be_empty
        expect(dossier.errors).to be_empty
      }
    end
  end
end
