# frozen_string_literal: true

describe 'Carte of a dossier', js: true do
  let(:instructeur) { instructeurs.default }
  let(:procedure) { create(:procedure, :published, :for_individual, :with_service, instructeurs: [instructeur], public_type_de_champs: [{ type: :carte }]) }
  let(:dossier) { create(:dossier, :en_construction, procedure:) }
  let(:champ) { dossier.champ_data.first }
  let(:description) { 'Un <b>jardin</b>' }
  let!(:geo_area) { create(:geo_area, :selection_utilisateur, :polygon, champ_data: champ, properties: { description: }) }

  before { login_as instructeur.user, scope: :user }

  scenario 'the instructeur finds the shapes on the map' do
    visit instructeur_dossier_path(procedure, dossier)

    expect(page).to have_css('.maplibregl-canvas')
    # The attribution stays behind its button until asked for.
    expect(page).to have_css('.maplibregl-ctrl-attrib.maplibregl-compact:not(.maplibregl-compact-show)')
    # Only the raster sources get credited here: the vector ones never load, as
    # the CSP of the test environment keeps their TileJSON out.
    find('.maplibregl-ctrl-attrib-button').click
    expect(find('.maplibregl-ctrl-attrib-inner')).to have_text('© IGN | MapLibre', exact: true)
    find('.maplibregl-ctrl-attrib-button').click
    hover_map_center { expect(page).to have_css('.maplibregl-popup', wait: 0) }

    within('.maplibregl-popup') do
      expect(page).to have_text(description)
      expect(page).to have_no_css('b')
    end

    # The shapes outlive a change of basemap.
    click_on 'Sélectionner les couches cartographiques'
    find('label', text: 'Vectoriel').click
    send_keys :escape
    hover_map_center { expect(page).to have_css('.maplibregl-popup', wait: 0) }

    # Move the map away from the shape, then come back to it from the list.
    2.times { drag_map(-300) }
    hover_map_center { expect(page).to have_no_css('.maplibregl-popup', wait: 0) }

    click_on geo_area.label
    hover_map_center { expect(page).to have_css('.maplibregl-popup', wait: 0) }
  end

  def drag_map(distance)
    page.driver.with_playwright_page do |pw_page|
      box = pw_page.locator('.maplibregl-canvas').bounding_box
      x = box['x'] + box['width'] / 2
      y = box['y'] + box['height'] / 2
      pw_page.mouse.move(x, y)
      pw_page.mouse.down
      pw_page.mouse.move(x + distance, y, steps: 10)
      pw_page.mouse.up
    end
  end

  # The popup follows the mouse moving over a shape, and the map takes time to
  # settle: keep moving until the expectation holds.
  def hover_map_center
    offset = 1
    page.document.synchronize do
      offset = -offset
      page.driver.with_playwright_page do |pw_page|
        box = pw_page.locator('.maplibregl-canvas').bounding_box
        pw_page.mouse.move(box['x'] + box['width'] / 2 + offset, box['y'] + box['height'] / 2)
      end
      yield
    rescue RSpec::Expectations::ExpectationNotMetError => error
      raise Capybara::ExpectationNotMet, error.message
    end
  end
end
