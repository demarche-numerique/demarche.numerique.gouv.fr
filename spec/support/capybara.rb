# frozen_string_literal: true

require 'capybara/rspec'
require 'capybara-screenshot/rspec'
require 'capybara/email/rspec'
require 'selenium/webdriver'

def setup_driver(app, download_path, options)
  Capybara::Selenium::Driver.new(app, browser: :chrome, options:).tap do |driver|
    if ENV['MAKE_IT_SLOW'].present?
      driver.browser.network_conditions = {
        offline: false,
        latency: 800,
        download_throughput: 1024000,
        upload_throughput: 1024000,
      }
    end

    if ENV['JS_LOG'].present?
      driver.browser.on_log_event(:console) do |event|
        puts event.args.join(" ") if event.type.in? ENV['JS_LOG'].downcase.split(',').map(&:to_sym)
      end
    end
  end
end

Capybara.register_driver :chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--no-sandbox') unless ENV['SANDBOX']
  options.add_argument('--mute-audio')
  options.add_argument('--window-size=1440,900')
  options.add_argument('--disable-search-engine-choice-screen')
  if ENV['NO_HEADLESS'].blank?
    options.add_argument('--headless')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-software-rasterizer')
  end

  download_path = Capybara.save_path
  # Chromedriver 77 requires setting this for headless mode on linux
  # Different versions of Chrome/selenium-webdriver require setting differently - just set them all
  options.add_preference('download.default_directory', download_path)
  options.add_preference(:download, default_directory: download_path)
  options.add_preference('intl.accept_languages', 'fr')

  setup_driver(app, download_path, options)
end

Capybara.default_max_wait_time = 6

Capybara.ignore_hidden_elements = false

Capybara.enable_aria_label = true

Capybara.disable_animation = true

# Save a snapshot of the HTML page when an integration test fails
Capybara::Screenshot.autosave_on_failure = true
# Keep only the screenshots generated from the last failing test suite
Capybara::Screenshot.prune_strategy = :keep_last_run
# Tell Capybara::Screenshot how to take screenshots when using the chrome driver
Capybara::Screenshot.register_driver :chrome do |driver, path|
  driver.save_screenshot(path)
end
# Tell Capybara::Screenshot how to take screenshots when using the playwright driver
Capybara::Screenshot.register_driver :playwright do |driver, path|
  driver.save_screenshot(path)
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    options = {
      browser_type: (ENV['PLAYWRIGHT_BROWSER'] || 'chromium').to_sym, # :chromium (default) or :firefox, :webkit
      headless: ENV['NO_HEADLESS'].blank?,
      locale: Rails.application.config.i18n.default_locale,
      downloadsPath: Capybara.save_path,
      playwright_cli_executable_path: 'bun --bun playwright',
    }

    driven_by(:playwright, options:)

    if ENV['LOG_WEB_CONSOLE'].present?
      Capybara.current_session.driver.with_playwright_page do |page|
        page.on("console", -> (msg) { puts msg.text })
      end
    end
  end

  config.before(:each, type: :system, chrome: true) do
    driven_by :chrome
  end

  # Examples tagged with :capybara_ignore_server_errors will allow Capybara
  # to continue when an exception in raised by Rails.
  # This allows to test for error cases.
  config.around(:each, :capybara_ignore_server_errors) do |example|
    Capybara.raise_server_errors = false

    example.run
  ensure
    Capybara.raise_server_errors = true
  end
end

Capybara.add_selector(:by_label) do
  xpath do |text|
    # 1. Element has aria-label="text"
    has_aria_label = XPath.attr(:'aria-label').equals(text)

    # 2. Element's id is referenced by a <label for="...">
    label_for = XPath.anywhere(:label)[XPath.string.n.is(text)].attr(:for)
    has_label_for = XPath.attr(:id).equals(label_for)

    # 3. Element's aria-labelledby points to a label/element whose text matches
    # Find the id of any element whose text is our target text
    labelling_element_id = XPath.anywhere[XPath.string.n.is(text)].attr(:id)
    has_aria_labelledby = XPath.attr(:'aria-labelledby').equals(labelling_element_id)

    XPath.descendant[has_aria_label | has_label_for | has_aria_labelledby]
  end
end
