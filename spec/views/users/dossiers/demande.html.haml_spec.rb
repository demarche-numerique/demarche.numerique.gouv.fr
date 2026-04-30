# frozen_string_literal: true

describe 'users/dossiers/demande', type: :view do
  let(:procedure) { create(:procedure, :published, :with_type_de_champ, :with_type_de_champ_private) }
  let(:dossier) { create(:dossier, :en_construction, :with_entreprise, procedure: procedure) }

  before do
    sign_in dossier.user
    assign(:dossier, dossier)
  end

  subject! { render }

  it 'renders the header' do
    expect(rendered).to have_text("Dossier n° #{dossier.id}")
  end

  it 'renders the dossier infos' do
    expect(rendered).to have_text('Déposé le')
    expect(rendered).to have_text('Identité')
    expect(rendered).to have_text('Votre dossier')
  end

  context 'when the dossier is editable' do
    it { is_expected.to have_link('Modifier le dossier', href: modifier_dossier_path(dossier)) }
  end

  context 'when the dossier is read-only' do
    let(:dossier) { create(:dossier, :en_instruction, :with_entreprise, procedure: procedure) }
    it { is_expected.not_to have_link('Modifier le dossier') }
  end

  context 'when the dossier has no depose_at date' do
    let(:dossier) { create(:dossier, :with_entreprise, procedure: procedure) }

    it { expect(rendered).not_to have_text('Déposé le') }
  end

  context 'when the user is logged in with FranceConnect' do
    let(:france_connect_information) { build(:france_connect_information) }
    let(:user) { build(:user, france_connect_informations: [france_connect_information]) }
    let(:procedure1) { create(:procedure, :with_type_de_champ, for_individual: true) }
    let(:dossier) { create(:dossier, procedure: procedure1, user: user) }

    before do
      render
    end

    it 'does not fill the individual with the informations from FranceConnect' do
      expect(rendered).not_to have_text("Le dossier a été déposé par le compte de #{france_connect_information.given_name} #{france_connect_information.family_name}, authentifié par FranceConnect")
    end
  end

  context 'when a dossier is for_tiers and the dossier is en_construction with email notification' do
    let(:dossier) { create(:dossier, :en_construction, :for_tiers_with_notification) }

    it 'displays the informations of the mandataire' do
      expect(rendered).to have_text('Identité du mandataire')
      expect(rendered).to have_text(dossier.mandataire_first_name.to_s)
      expect(rendered).to have_text(dossier.mandataire_last_name.to_s)
      expect(rendered).to have_text(dossier.individual.email.to_s)
    end
  end

  context 'when a dossier is accepte with motivation' do
    let(:dossier) { create(:dossier, :accepte, :with_motivation) }

    it 'displays the motivation' do
      expect(rendered).not_to have_text('Cette démarche est soumise à un accusé de lecture.')
      expect(rendered).to have_text('Motivation')
    end
  end

  context 'when a dossier is accepte with motivation and with accuse de lecture' do
    let(:dossier) { create(:dossier, :accepte, :with_motivation, procedure: create(:procedure, :accuse_lecture)) }

    it 'display information about accuse de lecture and not the motivation' do
      expect(rendered).to have_text('Cette démarche est soumise à un accusé de lecture.')
      expect(rendered).not_to have_text('Motivation')
      expect(rendered).not_to have_text('L’usager n’a pas encore pris connaissance de la décision concernant son dossier')
    end
  end

  context 'when there is a dropdown list from a referentiel' do
    let!(:procedure) { create(:procedure, types_de_champ_public:) }
    let(:types_de_champ_public) do
      [
        { type: :drop_down_list, drop_down_mode: 'advanced', drop_down_other: '1', referentiel: },
      ]
    end
    let(:dossier) { create(:dossier, procedure: procedure) }
    let(:champ) { dossier.champs.first }
    let(:referentiel) { create(:csv_referentiel, :with_items) }

    context 'user choose an option in the list' do
      before do
        dossier.champs.first.update!(value: referentiel.items.first.id.to_s)
        dossier.champs.first.referentiel = { 'data' => { 'row' => { 'option' => 'fromage', 'calorie_kcal' => '145', 'poids_g' => '60' }, 'headers' => ['Option', 'Calorie (kcal)', 'Poids (g)'] } }
        render
      end

      it 'display only the first option to the user' do
        expect(rendered).to have_text('fromage')
        expect(rendered).not_to have_text('dessert')
      end
    end

    context 'user choose other option' do
      before do
        dossier.champs.first.update!(value: '__other__', value_other: 'Texte libre')
        dossier.reload
        render
      end
      it 'display only the first option to the user' do
        expect(rendered).to have_text('Texte libre')
      end
    end
  end

  context 'when there is a multiple dropdown list from a referentiel' do
    let!(:procedure) { create(:procedure, types_de_champ_public:) }
    let(:types_de_champ_public) do
      [
        { type: :multiple_drop_down_list, drop_down_mode: 'advanced', referentiel: },
      ]
    end
    let(:dossier) { create(:dossier, procedure: procedure) }
    let(:champ) { dossier.champs.first }
    let(:referentiel) { create(:csv_referentiel, :with_items) }
    let(:value) { [referentiel.items.first.id.to_s, referentiel.items.second.id.to_s] }

    context 'user chooses two options in the list' do
      before do
        champ.update!(value: value.to_json)
        render
      end

      it 'displays two options to the user' do
        expect(rendered).to have_text('fromage, dessert')
        expect(rendered).not_to have_text('fruit')
      end
    end
  end

  context 'when value contains html values' do
    let(:types_de_champ_public) { [{ type: :textarea }] }
    let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }
    let(:champ) { dossier.project_champs_public.first }

    before do
      champ.update(value: '<strong>important</strong>')
      assign(:dossier, dossier)
      render
    end

    it 'renders the value escaped in the view' do
      # The raw HTML tags should not be interpreted as tags but escaped
      expect(rendered).to include('&lt;strong&gt;important&lt;/strong&gt;')
    end
  end
end
