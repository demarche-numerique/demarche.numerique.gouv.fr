# frozen_string_literal: true

describe Champs::EmailChamp do
  describe 'validation' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{}, { type: :email }, {}]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.root_public_champs.second }
    let(:value) { nil }
    before { champ.value = value }
    subject { champ.validate(:champ_value) }

    context 'when nil' do
      it { is_expected.to be_truthy }
    end

    context 'when value contains invalid email formats' do
      it 'rejects various invalid email formats' do
        invalid_emails = [
          'username',                                                    # no domain
          'username@mailserver',                                         # no extension
          "testing@example.com\u0022onmouseover=uzcc(96363)\u0022",      # pentest with quotes
          "testing@example.com<script>alert('ok')</script>",             # pentest with script
          "testing@example.com?test", # pentest with query
        ]

        invalid_emails.each do |email|
          champ.value = email
          expect(champ.validate(:champ_value)).to be_falsey
        end
      end
    end

    context 'when value contains various valid email formats' do
      it 'accepts different valid email formats' do
        valid_emails = [
          'username+alias@mailserver.fr',                    # alias
          'username+alias@demarches-simplifiees.fr',         # dash in domain
          'username+alias@demarches-simplifiees-v2.fr',      # multiple dashes
          'tech@démarches.gouv.fr',                          # accents
          'prenom.nom@etu.univ-rouen.fr',                    # complex domain
          'username@mailserver.domain', # classic format
        ]

        valid_emails.each do |email|
          champ.value = email
          expect(champ.validate(:champ_value)).to be_truthy
        end
      end
    end

    context 'when value contains white spaces plus a standard email' do
      let(:value) { "\r\n\t username@mailserver.domain\r\n\t " }
      it { is_expected.to be_truthy }
      it 'normalizes value on assignment' do
        expect(champ.value).to eq('username@mailserver.domain')
      end
    end

    context 'when type_de_champ is not in dossier revision anymore' do
      before {
        champ.update_column(:value, 'username')
        dossier.revision.remove_type_de_champ(champ.stable_id)
        dossier.reload
      }

      it 'is not projected, so the dossier does not validate the invalid value' do
        expect(dossier.validate(:champs_public_value)).to be_truthy
      end
    end
  end
end
