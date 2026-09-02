# frozen_string_literal: true

RSpec.describe TypeDeChamps::APIParticulierValidator do
  subject { procedure.validate(:public_type_de_champs_editor) }

  context 'when procedure has a API Particulier champ and a API Particulier token' do
    let(:procedure) { create(:procedure, :with_api_particulier_token, public_type_de_champs:) }
    let(:public_type_de_champs) { [{ type: :quotient_familial }] }

    it 'does not add errors to the procedure' do
      subject
      expect(procedure.errors).to be_empty
    end
  end

  context 'when procedure has a API Particulier champ but no API Particulier token' do
    let(:procedure) { create(:procedure, public_type_de_champs:) }
    let(:public_type_de_champs) { [{ type: :quotient_familial }] }

    it 'adds errors to the procedure' do
      subject
      expect(procedure.errors.details[:public_draft_type_de_champs])
        .to include(hash_including(error: :missing_api_particulier_token))
    end
  end

  context 'when procedure has a API Particulier champ and an unusable token' do
    # Une démarche déjà publiée avec un jeton illisible ne peut plus être republiée
    # sans le corriger.
    let(:procedure) do
      create(:procedure, public_type_de_champs:).tap do
        it.api_particulier_token = 'azertyuiopqsdfgh'
        it.save(validate: false)
      end
    end
    let(:public_type_de_champs) { [{ type: :quotient_familial }] }

    it 'adds errors to the procedure' do
      subject
      expect(procedure.errors.details[:public_draft_type_de_champs])
        .to include(hash_including(error: :missing_api_particulier_token))
    end
  end
end
