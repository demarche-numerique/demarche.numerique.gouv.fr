# frozen_string_literal: true

describe Procedure::Card::IneligibiliteDossierComponent, type: :component do
  include Logic

  subject { render_inline(described_class.new(procedure:)) }

  let(:procedure) { create(:procedure, public_type_de_champs:) }
  let(:public_type_de_champs) { [{ type: :yes_no }] }

  context 'when none of the public champs supports conditions' do
    let(:public_type_de_champs) { [] }

    it { is_expected.to have_css('p.fr-badge', text: 'Désactivé') }
  end

  context 'when ineligibilite is not enabled' do
    it { is_expected.to have_css('p.fr-badge', text: 'Désactivé') }
  end

  context 'when ineligibilite is enabled' do
    before { procedure.draft_revision.update!(ineligibilite_enabled: true, ineligibilite_message: 'Non éligible', ineligibilite_rules:) }

    context 'with valid rules' do
      let(:ineligibilite_rules) { ds_eq(constant(true), constant(true)) }

      it { is_expected.to have_css('p.fr-badge.fr-badge--success', text: 'Activé') }
    end

    context 'with invalid rules' do
      let(:ineligibilite_rules) { ds_eq(constant(true), constant(1)) }

      it { is_expected.to have_css('p.fr-badge.fr-badge--error', text: 'À modifier') }
    end
  end
end
