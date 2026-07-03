# frozen_string_literal: true

# Regression test for a bug where submitting a correction on one champ would
# silently "touch" an *untouched* blank champ of another type.
#
# Root cause: reading any `store_accessor` attribute (e.g. AddressChamp#country_code)
# on a champ whose JSON column is nil initializes that column to `{}`. When the
# buffer stream is merged, `dossier.save!` autosaves the now-dirty (but untouched)
# champ. For an address this was even worse: `set_full_address` defaulted
# `country_code` to 'FR', turning an empty optional champ into a filled "France"
# address shown as if the usager had entered it.
RSpec.describe 'A blank champ must not be touched when another champ is corrected', type: :model do
  let(:procedure) do
    create(:procedure, :published,
      types_de_champ_public: [
        { type: 'text', libelle: 'Texte', stable_id: 99 },
        { type: second_type, libelle: 'Second', stable_id: 100, mandatory: false },
      ])
  end
  let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
  let(:user) { dossier.user }

  def second_champ
    dossier.reload.champ_data.find { _1.stream == Dossier::MAIN_STREAM && _1.stable_id == 100 }
  end

  # Reproduces the usager correction flow: edit only the text champ on the user
  # buffer stream, validate the whole dossier (which reads every champ), then merge.
  def correct_text_only
    edited = Dossier.find(dossier.id)
    edited.with_update_stream(user) do
      edited.public_champ_data_for_update('99', updated_by: user.email).assign_attributes(value: 'corrigé')
    end
    edited.save!

    submitted = Dossier.find(dossier.id)
    submitted.champs_public_valid?
    submitted.merge_user_buffer_stream!
    submitted.save!
  end

  %w[address communes regions departements epci].each do |type|
    context "with a blank #{type} champ" do
      let(:second_type) { type }

      it "leaves the blank #{type} champ untouched and still blank" do
        dossier.champ_data.find { _1.stable_id == 100 }.update_columns(value: nil, value_json: nil, external_id: nil)
        updated_at_before = second_champ.updated_at

        travel_to(1.hour.from_now) { correct_text_only }

        expect(second_champ.value_json).to be_nil
        expect(second_champ.updated_at).to be_within(1.second).of(updated_at_before)
      end
    end
  end
end
