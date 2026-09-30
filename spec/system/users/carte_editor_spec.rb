# frozen_string_literal: true

describe 'Carte editor', js: true do
  let(:procedure) { create(:procedure, :published, :for_individual, public_type_de_champs: [{ type: :carte, libelle: 'Terrain' }]) }
  let(:dossier) { create(:dossier, :brouillon, :with_individual, procedure:) }

  before do
    login_as dossier.user, scope: :user
    visit brouillon_dossier_path(dossier)
    expect(page).to have_css('.maplibregl-canvas')
  end

  scenario 'the usager draws, describes and deletes a shape' do
    # The map must outlive the refresh of the champ after each save.
    page.execute_script("document.querySelector('.maplibregl-canvas').dataset.kept = 'true'")

    click_on 'Dessiner un polygone'
    click_map(-100, -60)
    click_map(100, -60)
    click_map(0, 80)
    send_keys :enter

    geo_area = wait_until { geo_areas.first }
    expect(geo_area).to have_attributes(source: 'selection_utilisateur')
    expect(geo_area.geometry['type']).to eq('Polygon')
    expect(geo_area.uuid).to match(/\A\h{8}-/)

    # The list comes back from the server with the label of the shape.
    fill_in "Description (#{geo_area.label})", with: 'Mon jardin'
    expect(page).to have_css('.maplibregl-canvas[data-kept]')
    wait_until { geo_areas.first&.description == 'Mon jardin' }

    # The description shows on hover, as in the reader.
    hover_map(0, -20) { expect(page).to have_css('.maplibregl-popup', text: 'Mon jardin', wait: 0) }

    click_map(0, 0)
    click_on 'Supprimer la forme sélectionnée'
    wait_until { geo_areas.empty? }
    expect(page).to have_no_field("Description (#{geo_area.label})")
  end

  scenario 'the usager undoes and redoes a change, and removes a shape from the list' do
    click_on 'Ajouter un point'
    click_map(0, 0)
    geo_area = wait_until { geo_areas.first }

    click_on 'Annuler la dernière modification'
    wait_until { geo_areas.empty? }
    click_on 'Rétablir la modification annulée'
    wait_until { geo_areas.size == 1 }

    dismiss_confirm { click_on "Supprimer #{geo_area.label}" }
    expect(geo_areas.size).to eq(1)
    accept_confirm("Supprimer « #{geo_area.label} » ?") { click_on "Supprimer #{geo_area.label}" }
    wait_until { geo_areas.empty? }
    expect(page).to have_no_button("Supprimer #{geo_area.label}")

    # A removal from the list is undone like any other change.
    click_on 'Annuler la dernière modification'
    wait_until { geo_areas.size == 1 }
  end

  scenario 'the usager imports the shapes of a file' do
    click_on 'Ajouter un fichier GPX ou KML'
    attach_file 'Choisir un fichier GPX ou KML', Rails.root.join('spec/fixtures/files/sample.kml')

    geo_area = wait_until { geo_areas.first }
    expect(geo_area.geometry).to eq('type' => 'Point', 'coordinates' => [2.3522, 48.8566, 0])
    expect(geo_area.filename).to end_with('sample.kml')

    click_on 'Supprimer le fichier'
    wait_until { geo_areas.empty? }
  end

  scenario 'a shape the server refuses is dropped with a message, and the rest is saved' do
    click_on 'Ajouter un fichier GPX ou KML'
    attach_file 'Choisir un fichier GPX ou KML', Rails.root.join('spec/fixtures/files/lambert93.kml')

    expect(page).to have_css('.fr-message--error', text: 'Une forme n’a pas été enregistrée : sa géométrie contient des coordonnées invalides')
    expect(geo_areas).to be_empty

    # The refused shape is gone from the editor: the next save goes through.
    click_on 'Ajouter un point'
    click_map(0, 0)
    wait_until { geo_areas.size == 1 }
    expect(page).to have_no_css('.fr-message--error')
  end

  def geo_areas
    GeoArea.where(champ_id: ChampData.where(dossier_id: dossier.id).select(:id)).to_a
  end

  # The popup follows the mouse, and the map takes time to settle: keep
  # moving until the expectation holds.
  def hover_map(dx, dy)
    jitter = 1
    page.document.synchronize do
      jitter = -jitter
      page.driver.with_playwright_page do |pw_page|
        box = pw_page.locator('.maplibregl-canvas').bounding_box
        pw_page.mouse.move(box['x'] + box['width'] / 2 + dx + jitter, box['y'] + box['height'] / 2 + dy)
      end
      yield
    rescue RSpec::Expectations::ExpectationNotMetError => error
      raise Capybara::ExpectationNotMet, error.message
    end
  end

  # Clicks the map at an offset from its center, in pixels.
  def click_map(dx, dy)
    page.driver.with_playwright_page do |pw_page|
      box = pw_page.locator('.maplibregl-canvas').bounding_box
      pw_page.mouse.click(box['x'] + box['width'] / 2 + dx, box['y'] + box['height'] / 2 + dy)
    end
  end
end
