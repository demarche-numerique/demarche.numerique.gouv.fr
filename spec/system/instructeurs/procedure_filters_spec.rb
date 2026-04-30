# frozen_string_literal: true

describe "procedure filters" do
  let(:instructeur) { create(:instructeur) }
  let(:procedure) { create(:procedure, :published, :with_labels, types_de_champ_public:, instructeurs: [instructeur]) }
  let(:types_de_champ_public) { [{ type: :text }] }
  let!(:type_de_champ) { procedure.active_revision.types_de_champ_public.first }
  let!(:new_unfollow_dossier) { create(:dossier, procedure: procedure, state: Dossier.states.fetch(:en_instruction)) }
  let!(:champ) { Champ.find_by(stable_id: type_de_champ.stable_id, dossier_id: new_unfollow_dossier.id) }
  let!(:new_unfollow_dossier_2) { create(:dossier, procedure: procedure, state: Dossier.states.fetch(:en_instruction)) }
  let!(:champ_2) { Champ.find_by(stable_id: type_de_champ.stable_id, dossier_id: new_unfollow_dossier_2.id) }

  before do
    champ.update(value: "Mon champ rempli")
    champ_2.update(value: "Mon autre champ rempli différemment")
    login_as(instructeur.user, scope: :user)
    visit instructeur_procedure_path(procedure)
  end

  scenario "should display demandeur by default" do
    within ".dossiers-table" do
      expect(page).to have_button("Demandeur")
      expect(page).to have_link(new_unfollow_dossier.user.email)
    end
  end

  scenario "should display sva by default if procedure has sva enabled" do
    procedure.update!(sva_svr: SVASVRConfiguration.new(decision: :sva).attributes)
    visit instructeur_procedure_path(procedure)
    within ".dossiers-table" do
      expect(page).to have_button("Date décision SVA")
      expect(page).to have_link(new_unfollow_dossier.user.email)
    end
  end

  scenario "should list all dossiers" do
    within ".dossiers-table" do
      expect(page).to have_link(new_unfollow_dossier.id.to_s)
      expect(page).to have_link(new_unfollow_dossier.user.email)

      expect(page).to have_link(new_unfollow_dossier_2.id.to_s)
      expect(page).to have_link(new_unfollow_dossier_2.user.email)
    end
  end

  scenario "should add be able to add created_at column", js: true do
    add_column("Date de création")
    within ".dossiers-table" do
      expect(page).to have_button("Date de création")
      expect(page).to have_link(I18n.l(new_unfollow_dossier.created_at, format: :short_with_time))
    end
  end

  scenario "should add be able to add and remove custom type_de_champ column", js: true do
    # Hack to force filters combo to be above the menu so Enregistrer button
    # is clickable. (by default height is 2000+ for playwright driver)
    Capybara.page.current_window.resize_to(1440, 900)

    add_column(type_de_champ.libelle)
    within ".dossiers-table" do
      expect(page).to have_button(type_de_champ.libelle)
      expect(page).to have_link(champ.value)
    end

    remove_column(type_de_champ.libelle)
    within ".dossiers-table" do
      expect(page).not_to have_button(type_de_champ.libelle)
      expect(page).not_to have_link(champ.value)
    end

    # Test removal of all customizable fields
    remove_column("Demandeur")
    within ".dossiers-table" do
      expect(page).not_to have_button("Demandeur")
    end
  end

  scenario "should be able to add and remove filter", js: true do
    add_filter("formulaire-usager", type_de_champ.libelle)

    add_filter_value(type_de_champ.libelle, champ.value, type: :text)

    within ".dossiers-table" do
      expect(page).to have_link(new_unfollow_dossier.id.to_s, exact: true)
      expect(page).to have_link(new_unfollow_dossier.user.email)

      expect(page).not_to have_link(new_unfollow_dossier_2.id.to_s, exact: true)
      expect(page).not_to have_link(new_unfollow_dossier_2.user.email)
    end

    clear_filter(champ.value)

    within ".dossiers-table" do
      expect(page).to have_link(new_unfollow_dossier.id.to_s)
      expect(page).to have_link(new_unfollow_dossier.user.email)

      expect(page).to have_link(new_unfollow_dossier_2.id.to_s)
      expect(page).to have_link(new_unfollow_dossier_2.user.email)
    end
  end

  describe 'with dropdown' do
    let(:types_de_champ_public) { [{ type: :drop_down_list }] }

    scenario "should be able to user custom filters", js: true do
      # use date filter
      add_filter("informations-dossier", "Date de passage en construction")
      add_filter_value("Le", "2010-10-10", type: :date)

      # use statut dropdown filter
      add_filter("informations-dossier", 'Labels')
      add_filter_value('Labels', 'Complet', type: :multi_select)

      # use choice dropdown filter
      add_filter("formulaire-usager", 'Choix unique')
      add_filter_value('Choix unique', 'val1', type: :multi_select)
    end
  end

  describe 'with repetition' do
    let(:types_de_champ_public) { [{ type: :repetition, libelle: 'Enfants', children: [{ libelle: 'Nom' }] }] }

    scenario "should be able to user custom fiters", js: true do
      add_filter("formulaire-usager", 'Enfants – Nom')
      add_filter_value('Enfants – Nom', 'Greer')
    end
  end

  describe 'with a vcr cached cassette' do
    describe 'departements' do
      let(:types_de_champ_public) { [{ type: :departements }] }
      scenario "should be able to find by departements with custom enum lookup", js: true do
        departement_champ = new_unfollow_dossier.champs.find(&:departements?)
        departement_champ.update!(value: 'Oise', external_id: '60')
        departement_champ.reload
        champ_select_value = "#{departement_champ.external_id} – #{departement_champ.value}"

        add_filter("formulaire-usager", departement_champ.libelle)
        add_filter_value(departement_champ.libelle, champ_select_value)

        expect(page).to have_link(new_unfollow_dossier.id.to_s)
      end
    end

    describe 'rna' do
      let(:types_de_champ_public) { [{ type: :rna }] }
      scenario "should be able to find by rna addresse with custom enum lookup", js: true do
        rna_champ = new_unfollow_dossier.champs.find(&:rna?)
        rna_champ.update!(
          value: 'W412005131',
          value_json: {
            "city_code" => "37261",
            "city_name" => "Tours",
            "postal_code" => "37000",
            "region_code" => "24",
            "region_name" => "Centre-Val de Loire",
            "street_name" => "fake",
            "street_number" => "fake",
            "street_address" => "fake",
            "department_code" => "37",
            "department_name" => "Indre-et-Loire",
          }
        )
        rna_champ.reload
        champ_select_value = "37 – Indre-et-Loire"

        add_filter("formulaire-usager", rna_champ.libelle)
        add_filter_value(rna_champ.libelle, champ_select_value)

        expect(page).to have_link(new_unfollow_dossier.id.to_s)
      end
    end

    describe 'region' do
      let(:types_de_champ_public) { [{ type: :regions }] }
      scenario "should be able to find by region with custom enum lookup", js: true do
        region_champ = new_unfollow_dossier.champs.find(&:regions?)
        region_champ.update!(value: 'Bretagne', external_id: '53')
        region_champ.reload

        add_filter("formulaire-usager", region_champ.libelle)
        add_filter_value(region_champ.libelle, region_champ.value)

        expect(page).to have_link(new_unfollow_dossier.id.to_s)
      end
    end
  end

  describe 'dossier labels' do
    scenario "should be able to filter by dossier labels", js: true do
      DossierLabel.create!(dossier_id: new_unfollow_dossier.id, label_id: procedure.labels.first.id)
      add_filter("informations-dossier", 'Labels')
      add_filter_value('Labels', procedure.labels.first.name, type: :multi_select)
      expect(page).to have_link(new_unfollow_dossier.id.to_s)
      expect(page).not_to have_link(new_unfollow_dossier_2.id.to_s, exact: true)
    end

    scenario "cumule les valeurs ajoutées séquentiellement sur un filtre multi-sélection", js: true do
      first_label = procedure.labels.first
      second_label = procedure.labels.second

      DossierLabel.create!(dossier: new_unfollow_dossier, label: first_label)
      DossierLabel.create!(dossier: new_unfollow_dossier_2, label: second_label)

      add_filter("informations-dossier", 'Labels')

      add_filter_value('Labels', first_label.name, type: :multi_select)

      within ".dossiers-table" do
        expect(page).to have_link(new_unfollow_dossier.id.to_s, exact: true)
        expect(page).not_to have_link(new_unfollow_dossier_2.id.to_s, exact: true)
      end

      add_filter_value('Labels', second_label.name, type: :multi_select)

      within ".dossiers-table" do
        expect(page).to have_link(new_unfollow_dossier.id.to_s, exact: true)
        expect(page).to have_link(new_unfollow_dossier_2.id.to_s, exact: true)
      end
    end
  end

  def add_filter_value(column_name, filter_value, type: :text)
    case type
    when :text, :date
      fill_in column_name, with: filter_value
      find_field(column_name).send_keys(:enter)
    when :multi_select
      select_combobox(column_name, filter_value)
    else
      raise "invalid type: #{type}"
    end
  end

  def add_filter(filter_select_category, column_name)
    raise "invalid filter select category: #{filter_select_category}" unless filter_select_category.in?(['informations-dossier', 'informations-usager', 'formulaire-usager', 'private-annotations'])

    click_on 'Personnaliser'

    expect(page).to have_content("Personnaliser les critères de recherche / filtres ")

    within "#form-#{filter_select_category}" do
      select column_name, from: "select-#{filter_select_category}"
      expect(page).to have_button("Ajouter", disabled: false)
      click_button "Ajouter"
    end

    within "#selected-filters" do
      expect(page).to have_content(column_name)
    end

    within ".padded-fixed-footer" do
      click_button "Valider"
    end
  end

  def clear_filter(filter_value)
    click_button text: filter_value
  end

  def add_column(column_name)
    click_on 'Personnaliser le tableau'
    select_autocomplete('Colonne à afficher', column_name)
    click_button "Enregistrer"
  end

  def remove_column(column_name)
    click_on 'Personnaliser le tableau'
    within '.fr-tag-list' do
      find('.fr-tag', text: column_name).find('button').click
    end
    click_button "Enregistrer"
  end

  scenario "should be able to access filter customization page", js: true do
    # Click on the "Personnaliser" button for filters
    click_on 'Personnaliser', match: :first

    # Test that we are redirected to the customize_filters page
    expect(page).to have_current_path(/\/procedure_presentation\/\d+\/customize_filters\?statut=a-suivre/)

    # Verify we're on the customization page with the correct content
    expect(page).to have_content("Personnaliser les critères de recherche / filtres")
    expect(page).to have_content("Votre sélection de critères")

    # Check that we have the 3 default filters in the correct order listed on the page
    within "#selected-filters" do
      expect(page).to have_content(/(État du dossier).*(N° dossier).*(Notifications sur le dossier)/)
    end

    # Delete the "N° dossier" filter
    within "#selected-filters" do
      # Find the filter box containing "N° dossier" and click its delete button
      within ".filter-box", text: "N° dossier" do
        find('button.fr-icon-delete-line').click
      end

      # Check that the "N° dossier" filter is deleted
      expect(page).not_to have_content("N° dossier")
    end

    # Add a new filter
    within "#form-informations-usager" do
      select "Demandeur", from: "select-informations-usager"
      expect(page).to have_button("Ajouter", disabled: false)
      click_button "Ajouter"
    end

    # Check that the filter is added
    within "#selected-filters" do
      expect(page).to have_content(/(État du dossier).*(Notifications sur le dossier).*(Demandeur)/)
    end

    # Move up the Demandeur filter
    within ".filter-box", text: "Demandeur" do
      find('button.fr-icon-arrow-up-line').click
    end

    within "#selected-filters" do
      expect(page).to have_content(/(État du dossier).*(Demandeur).*(Notifications sur le dossier)/)
    end

    # Move down the État du dossier filter
    within ".filter-box", text: "État du dossier" do
      find('button.fr-icon-arrow-down-line').click
    end

    within "#selected-filters" do
      expect(page).to have_content(/(Demandeur).*(État du dossier).*(Notifications sur le dossier)/)
    end

    # Click on the "Valider" button it should redirect to the procedure page
    within ".padded-fixed-footer" do
      click_button "Valider"
    end

    expect(page).to have_current_path(instructeur_procedure_path(procedure))

    # Check that the filters are available in the editable-filters-component
    within "#editable-filters-component" do
      # Regex to check that the filters are displayed in the order they were added
      expect(page).to have_content(/(Demandeur).*(État du dossier).*(Notifications sur le dossier)/)
      expect(page).not_to have_content("N° dossier")
    end
  end
end
