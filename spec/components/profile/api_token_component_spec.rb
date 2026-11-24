# frozen_string_literal: true

RSpec.describe Profile::APITokenComponent, type: :component do
  let(:api_token) { APIToken.generate(administrateurs.default, allowed_procedure_ids: [procedures.individual.id]).first }

  subject { render_inline(described_class.new(api_token:)) }

  context 'when the token was used 3 hours ago' do
    before { api_token.update_column(:last_v2_authenticated_at, 3.hours.ago) }

    it { expect(subject).to have_text('utilisé il y a 3 heures') }
  end
end
