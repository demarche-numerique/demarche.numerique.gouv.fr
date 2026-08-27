# frozen_string_literal: true

describe 'users/dossiers/identite', type: :view do
  let(:dossier) { create(:dossier, :with_service, state: Dossier.states.fetch(:brouillon), procedure: procedure) }

  before do
    sign_in dossier.user
    assign(:dossier, dossier)
    allow(view).to receive(:logged_in_with_pro_connect?).and_return(false)
  end

  subject! { render }

  context 'when procedure has for_tiers_enabled' do
    let_it_be(:procedure) { procedures.individual }

    it 'has choice for you or a tiers' do
      expect(rendered).to have_content "Pour vous"
      expect(rendered).to have_content "Pour une autre personne"
      expect(rendered).to have_content "Vous déposez ce dossier pour un bénéficiaire en tant que mandataire"

      # does not pre-check any radio
      expect(rendered).not_to have_checked_field("radio-self-manage")
      expect(rendered).not_to have_checked_field("radio-tiers-manage")

      # not show identity form until a choice is made'
      expect(rendered).not_to have_text("Votre identité")
    end

    it 'shows a disabled continue button' do
      expect(rendered).to have_button("Continuer", disabled: true)
    end
  end

  context 'when procedure has for_tiers_enabled and identity already set' do
    let(:procedure) { procedures.individual }
    let(:dossier) { create(:dossier, :with_service, :with_individual, state: Dossier.states.fetch(:brouillon), procedure: procedure, identity_updated_at: Time.current) }

    it 'hides the continue button group' do
      expect(rendered).to have_css('#identite-buttons-group.hidden')
      expect(rendered).to have_css('form#identite-form')

      expect(rendered).to have_checked_field("radio-self-manage")
      expect(rendered).not_to have_checked_field("radio-tiers-manage")
    end

    context 'when the demarche asks for the birthdate' do
      let(:procedure) { create(:simple_procedure, for_individual: true, ask_birthday: true) }

      it 'has a birthday field' do
        expect(rendered).to have_field('Date de naissance')
      end
    end
  end

  context 'when procedure has for_tiers_enabled and identity already set for tiers' do
    let(:procedure) { procedures.individual }
    let(:dossier) do
      create(:dossier, :with_service, :with_individual,
             for_tiers: true,
             mandataire_first_name: 'John',
             mandataire_last_name: 'Doe',
             identity_updated_at: Time.current,
             state: Dossier.states.fetch(:brouillon),
             procedure: procedure)
    end

    it 'checks the tiers radio' do
      expect(rendered).to have_checked_field("radio-tiers-manage")
      expect(rendered).not_to have_checked_field("radio-self-manage")
    end
  end

  context 'when procedure does not have for_tiers_enabled' do
    let(:procedure) { create(:simple_procedure, :for_individual, for_tiers_enabled: false) }

    it 'does not show for_tiers choice' do
      expect(rendered).not_to have_content "Pour vous"
      expect(rendered).not_to have_content "Pour une autre personne"
    end

    it 'has identity fields' do
      within('.individual-infos') do
        expect(rendered).to have_field(id: 'Prenom')
        expect(rendered).to have_field(id: 'Nom')
      end
    end
  end
end
