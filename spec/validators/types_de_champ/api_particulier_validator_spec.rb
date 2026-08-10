# frozen_string_literal: true

RSpec.describe TypesDeChamp::APIParticulierValidator do
  subject { procedure.validate(:public_types_de_champ_editor) }

  context 'when procedure has a API Particulier champ and a API Particulier token' do
    let(:procedure) { create(:procedure, :with_api_particulier_token, types_de_champ_public:) }
    let(:types_de_champ_public) { [{ type: :quotient_familial }] }

    it 'does not add errors to the procedure' do
      subject
      expect(procedure.errors).to be_empty
    end
  end

  context 'when procedure has a API Particulier champ but no API Particulier token' do
    let(:procedure) { create(:procedure, types_de_champ_public:) }
    let(:types_de_champ_public) { [{ type: :quotient_familial }] }

    it 'adds errors to the procedure' do
      subject
      expect(procedure.errors.details[:draft_public_types_de_champ])
        .to include(hash_including(error: :missing_api_particulier_token))
    end
  end
end
