# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TypesDeChamp::ReferentielReadyValidator do
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:referentiel) { create(:api_referentiel, :exact_match) }
  let(:types_de_champ_public) { [{ type: :referentiel, referentiel: }] }

  subject { procedure.validate(:public_types_de_champ_editor) }

  context 'when all referentiel is ready' do
    before { expect_any_instance_of(Referentiels::APIReferentiel).to receive(:ready?).and_return(true) }

    it 'does not add errors to the procedure' do
      expect { subject }.not_to change { procedure.errors.count }
    end
  end

  context 'when all referentiel is not ready' do
    before { expect_any_instance_of(Referentiels::APIReferentiel).to receive(:ready?).and_return(false) }

    it 'does not add errors to the procedure' do
      expect { subject }.to change { procedure.errors.count }
    end
  end
end
