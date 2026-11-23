# frozen_string_literal: true

describe AdministrateurCreationRequestJob do
  let(:creation_request) do
    AdministrateurCreationRequest.create!(requester: create(:super_admin), emails: ['new.admin@numerique.gouv.fr'], state: :approved)
  end

  it 'creates the accounts of the request' do
    described_class.perform_now(creation_request)

    expect(creation_request.reload.results).to eq('new.admin@numerique.gouv.fr' => 'created')
  end
end
