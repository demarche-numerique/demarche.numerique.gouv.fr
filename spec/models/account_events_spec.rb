# frozen_string_literal: true

describe 'Account events', type: :model do
  let(:event_store) { Events.store }

  describe 'jeton_api_cree and jeton_api_revoque' do
    let(:administrateur) { administrateurs.blank }

    it 'records the generation and the revocation of a token, by its administrateur' do
      api_token, = APIToken.generate(administrateur, expires_at: 1.month.from_now.to_date)
      api_token.revoke!

      expect(event_store).to have_published(
        an_event(Events::JetonAPICree)
          .with_data(administrateur_id: administrateur.id, api_token_id: api_token.id, expires_at: api_token.expires_at)
          .with_metadata(actor: { type: 'Administrateur', id: administrateur.id }),
        an_event(Events::JetonAPIRevoque)
          .with_data(api_token_id: api_token.id)
          .with_metadata(actor: { type: 'Administrateur', id: administrateur.id })
      ).in_stream(Events.stream('Administrateur', administrateur.id))
      expect(APIToken.exists?(api_token.id)).to be(false)
    end

    it 'does not link twice an event the administrateur records on their own stream' do
      expect { APIToken.generate(administrateur, expires_at: 1.month.from_now.to_date) }
        .to change { event_store.read.stream(Events.stream('Administrateur', administrateur.id)).count }.by(1)
    end
  end
end
