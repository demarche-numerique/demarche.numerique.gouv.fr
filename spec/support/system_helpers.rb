# frozen_string_literal: true

module SystemHelpers
  include ActiveJob::TestHelper

  def sign_in_with(email, password, sign_in_by_link = false)
    fill_in :user_email, with: email
    fill_in :user_password, with: password

    if sign_in_by_link
      User.find_by(email: email)&.instructeur&.update!(bypass_email_login_token: false)
    end

    perform_enqueued_jobs do
      click_on 'Se connecter'
      expect(page).to have_text("Voir mon profil")
    end

    if sign_in_by_link
      mail = ActionMailer::Base.deliveries.last
      message = mail.html_part.body.raw_source
      match = message.match %r{/connexion-par-jeton/(?<instructeur_id>\d+)\?jeton=(?<jeton>\w+)}

      instructeur_id = match[:instructeur_id]
      jeton = match[:jeton]

      visit sign_in_by_link_path(instructeur_id, jeton:)
    end
  end

  def sign_up_with(email, password = SECURE_PASSWORD)
    fill_in :user_email, with: email
    fill_in :user_password, with: password

    perform_enqueued_jobs do
      click_button 'Créer un compte'
    end
  end

  def click_verification_link_for(email)
    verification_email = open_email(user.email)
    verification_link = verification_email.text.match(%r{\s+(\S+\/users\/confirm_email/\S+)\s+})[1]

    visit URI.parse(verification_link).request_uri
  end

  def click_confirmation_link_for(email, in_another_browser: false)
    confirmation_email = open_email(email)
    confirmation_link = confirmation_email.text.match(%r{\s+(\S+\/users\/confirmation\S+)\s+})[1]

    if in_another_browser
      # Simulate the user opening the link in another browser, thus loosing the session cookie
      Capybara.reset_session!
    end

    visit URI.parse(confirmation_link).request_uri
  end

  def click_procedure_sign_in_link_for(email)
    confirmation_email = open_email(email)
    procedure_sign_in_link = confirmation_email.body.match(/href="([^"]*\/commencer\/[^"]*)"/)[1]

    visit URI.parse(procedure_sign_in_link).request_uri
  end

  def click_reset_password_link_for(email)
    reset_password_email = open_email(email)
    reset_password_url = reset_password_email.body.match(/http[s]?:\/\/[^\/]+(\/[^\s]+reset_password_token=[^\s"]+)/)[1]

    visit reset_password_url
  end

  # Add a new type de champ in the procedure editor
  def add_champ
    click_on 'Ajouter un champ'
  end

  # Pick a type in the editor's "Type de champ" menu, a React Select with a
  # search field. `from:` is the trigger id (dom_id(tdc, :type_champ)) when
  # the page holds several fields and the first one is not the target.
  def select_type_de_champ(libelle, from: nil)
    trigger_id = from || find('label', exact_text: 'Type de champ', match: :first)['for']
    find_by_id(trigger_id).click

    # the menu is portaled to the body, out of any `within` scope
    popover = page.document.find('.select-popover')
    popover.find('input').set(libelle)
    popover.find('[role="option"]', exact_text: libelle).click
  end

  def hide_autonotice_message
    expect(page).to have_text('Formulaire enregistré')
    execute_script("document.querySelector('#autosave-notice').classList.add('hidden');")
  end

  # DSFR wires its dialogs asynchronously: a `<dialog class="fr-modal">` only
  # becomes operable once DSFR has stamped it with `data-fr-js-modal`. A trigger
  # clicked before that either does nothing at all, or (for triggers routed
  # through a Stimulus controller) waits for DSFR before disclosing the modal —
  # so on a slow bundle the modal opens after Capybara has given up. Waiting for
  # the stamp puts the wait where the latency actually is.
  def open_dsfr_modal(selector)
    # generous wait: what we are really waiting for here is the JS bundle
    expect(page).to have_selector("#{selector}[data-fr-js-modal='true']", visible: :all, wait: 10)
    yield
    expect(page).to have_selector(selector, visible: true)
  end

  # A turbo-poll response can refresh the whole page (turbo_stream.refresh),
  # which is a problem for anything the server renders exactly once: a poll
  # landing at the wrong moment consumes that render before the spec ever looks
  # at it. Answer polls with 204 in the browser — turbo-poll treats that as
  # "nothing to render" — so they never reach the server. Call this before the
  # first poll can fire (i.e. in a before hook, not around the assertions), and
  # open a with_turbo_poll block where the spec does want polling.
  def suppress_turbo_poll
    page.driver.with_playwright_page do |pw_page|
      pw_page.route(POLLING_URL_PATTERN, -> (route, _request) { route.fulfill(status: 204, body: '') })
    end
  end

  # Let polls reach the server for the duration of the block. Re-attaching the
  # controllers makes the next poll immediate instead of one interval away.
  def with_turbo_poll
    page.driver.with_playwright_page { |pw_page| pw_page.unroute(POLLING_URL_PATTERN) }
    page.execute_script(<<~JS)
      document.querySelectorAll('[data-controller~="turbo-poll"]').forEach((el) => {
        const value = el.getAttribute('data-controller');
        el.removeAttribute('data-controller');
        requestAnimationFrame(() => el.setAttribute('data-controller', value));
      });
    JS

    yield
  ensure
    suppress_turbo_poll
  end

  POLLING_URL_PATTERN = %r{/polling}

  def blur
    if page.has_css?('body', wait: 0)
      page.find('body').click
    else # page after/inside a `within` block does not match body
      page.first('div').click
    end
  end

  def playwright_debug
    page.driver.with_playwright_page do |page|
      page.context.enable_debug_console!
      page.pause
    end
  end

  def pause
    $stderr.write 'Spec paused. Press enter to continue:'
    $stdin.gets
  end

  def wait_until
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep(0.1) until (value = yield)
      value
    end
  end

  def select_combobox(libelle, value, custom_value: false)
    fill_in libelle, with: custom_value ? "#{value}," : value
    expect(page).to have_field(libelle, with: value) if !custom_value

    if !custom_value
      within '[role="listbox"]' do
        option = find('[role="option"]', text: value)
        expect(option).to be_visible
        sleep 0.1 # wait for any animation to complete
        option.click
        option.send_keys(:escape) if attached?(option)
      end
    end
  end

  def attached?(node)
    node.text # or any method that touches the node
    true
  rescue Capybara::Playwright::Node::StaleReferenceError
    false
  end

  def select_autocomplete(libelle, value)
    label = find(:by_label, libelle, match: :first)
    scroll_to(label)
    label.click
    page.active_element.send_keys(value)

    within '[role="listbox"]' do
      option = find('[role="option"]', text: value)
      expect(option).to be_visible
      sleep 0.1 # wait for any animation to complete
      option.click
      option.send_keys(:escape)
      option.send_keys(:escape)
    end
  end

  def log_out
    within('.fr-header .fr-container .fr-header__tools .fr-btns-group') do
      scroll_to(find('button[title="Mon profil"]'), align: :center)
      click_button(title: 'Mon profil')
      expect(page).to have_selector('#account.fr-collapse--expanded', visible: true)
      scroll_to(find('button[title="Mon profil"]'), align: :center)
      click_on 'Se déconnecter'
    end
    expect(page).to have_current_path(root_path, wait: 30)
  end

  def find_hidden_field_for(libelle, name: 'value')
    find("#{form_group_id_for(libelle)} input[type=\"hidden\"][name$=\"[#{name}]\"]")
  end

  def form_group_id_for(libelle)
    "#champ-#{form_id_for(libelle).gsub('-input', '')}"
  end

  def form_id_for(libelle)
    find(:xpath, ".//label[contains(text()[normalize-space()], '#{libelle}')]")[:for]
  end

  def wait_for_autosave
    blur
    expect(page).to have_css('.debounced-empty') # no more debounce
  end

  # find input (radio), center it in the screen, then click on label (otherwise element out of scope)
  def custom_check(field_id)
    scroll_to(find_field(field_id), align: :center)
    find("label[for=#{field_id}]").click
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system

  config.before(:each, type: :system) do
    stub_request(:post, WEASYPRINT_URL).to_return(body: '%PDF-1.4 fake pdf for tests') if WEASYPRINT_URL.present?
  end
end
