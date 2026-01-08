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
      instructeur_id = message[/".+\/connexion-par-jeton\/(.+)\?jeton=(.*)"/, 1]
      jeton = message[/".+\/connexion-par-jeton\/(.+)\?jeton=(.*)"/, 2]

      visit sign_in_by_link_path(instructeur_id, jeton: jeton)
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

  def hide_autonotice_message
    expect(page).to have_text('Formulaire enregistré')
    execute_script("document.querySelector('#autosave-notice').classList.add('hidden');")
  end

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
      end
    end
  end

  def select_autocomplete(libelle, value)
    label = find('label', text: libelle)
    scroll_to(label)
    label.click

    within '[role="listbox"]' do
      option = find('[role="option"]', text: value)
      expect(option).to be_visible
      sleep 0.1 # wait for any animation to complete
      option.click
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

  # Keep the brower window open after a test success of failure, to
  # allow inspecting the page or the console.
  #
  # Usage:
  #  1. Disable the 'headless' mode in `spec_helper.rb`
  #  2. Call `leave_browser_open` at the beginning of your scenario
  def leave_browser_open
    Selenium::WebDriver::Chrome::Service.class_eval do
      def stop
        STDOUT.puts "#{self.class}#stop is a no-op, because leave_browser_open is enabled"
      end
    end

    Selenium::WebDriver::Driver.class_eval do
      def quit
        STDOUT.puts "#{self.class}#quit is a no-op, because leave_browser_open is enabled"
      end
    end

    Capybara::Selenium::Driver.class_eval do
      def reset!
        STDOUT.puts "#{self.class}#reset! is a no-op, because leave_browser_open is enabled"
      end
    end
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
    expect(page).to have_css('.autosave-state-idle') # no more in flight promise
  end

  # find input (radio), center it in the screen, then click on label (otherwise element out of scope)
  def custom_check(field_id)
    scroll_to(find_field(field_id), align: :center)
    find("label[for=#{field_id}]").click
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system
end
