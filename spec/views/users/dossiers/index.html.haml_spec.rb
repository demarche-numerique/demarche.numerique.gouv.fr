# frozen_string_literal: true

describe 'users/dossiers/index', type: :view do
  let(:user) { create(:user) }
  let(:dossier_brouillon) { create(:dossier, state: Dossier.states.fetch(:brouillon), user: user) }
  let(:dossier_en_construction) { create(:dossier, state: Dossier.states.fetch(:en_construction), user: user) }
  let(:dossier_termine) { create(:dossier, state: Dossier.states.fetch(:accepte), user: user) }
  let(:user_dossiers) { [dossier_brouillon, dossier_en_construction, dossier_termine] }
  let(:filter) { Users::DossierFilterService.new(user: user, params: ActionController::Parameters.new) }

  before do
    allow(view).to receive(:new_demarche_url).and_return('#')
    allow(view).to receive(:filter_params_slice).and_return(ActionController::Parameters.new.permit!)
    allow(controller).to receive(:current_user) { user }
    assign(:dossiers, Kaminari.paginate_array(user_dossiers).page(1))
    assign(:total_count, user_dossiers.size)
    assign(:filter, filter)
    assign(:procedures_for_select, user_dossiers.map(&:procedure))
    assign(:corbeille_count, 0)
    assign(:pending_transfers_count, 0)
    assign(:counts, { procedure_ids: {}, states: {}, alerts: {}, shared_with_me: 0 })

    render
  end

  it 'affiche les dossiers' do
    expect(rendered).to have_selector('.card', count: 3)
  end

  it 'affiche les informations des dossiers' do
    expect(rendered).to have_text(dossier_brouillon.id.to_s)
    expect(rendered).to have_text(dossier_brouillon.procedure.libelle)
    expect(rendered).to have_link(dossier_brouillon.procedure.libelle, href: brouillon_dossier_path(dossier_brouillon))

    expect(rendered).to have_text(dossier_en_construction.id.to_s)
    expect(rendered).to have_text(dossier_en_construction.procedure.libelle)
    expect(rendered).to have_link(dossier_en_construction.procedure.libelle, href: dossier_path(dossier_en_construction))
  end

  it 'affiche le titre Mes dossiers' do
    expect(rendered).to have_selector('h1', text: 'Mes dossiers')
  end

  it 'shows the dossier count without pagination on a single page' do
    expect(rendered).to have_selector('.results-count', text: '3 dossiers')
    expect(rendered).not_to have_text('sur 3 dossiers')
  end

  context 'when the list is paginated (more than 25 dossiers)' do
    before do
      assign(:dossiers, Kaminari.paginate_array(user_dossiers, total_count: 30).page(1).per(25))
      assign(:total_count, 30)
      render
    end

    it 'shows the "1 - X of XX dossiers" indication' do
      expect(rendered).to have_selector('.results-count', text: 'sur 30 dossiers')
    end
  end

  context 'quand il n’y a aucun dossier' do
    let(:user_dossiers) { [] }

    it 'affiche un message' do
      expect(rendered).to have_text('Aucun dossier')
    end
  end

  context 'avec un dossier traité' do
    let(:user_dossiers) { [dossier_termine] }

    it 'affiche le bouton Mettre à la corbeille' do
      expect(rendered).to have_text('Mettre à la corbeille')
    end
  end
end
