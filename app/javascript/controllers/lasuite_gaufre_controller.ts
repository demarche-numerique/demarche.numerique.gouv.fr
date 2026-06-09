import { Controller } from '@hotwired/stimulus';

import darkCss from './lasuite_gaufre_dark.css?inline';

// Ids of the trigger buttons rendered in the header (mobile + desktop).
const BUTTON_IDS = ['lasuite-gaufre-mobile', 'lasuite-gaufre-desktop'];

// Id the widget gives its Shadow DOM host once it has booted.
const SHADOW_HOST_ID = 'lasuite-widget-lagaufre-shadow';

// The widget is a single instance keyed by name; initializing it twice would bind
// two panels that toggle together. This module-level flag keeps init to once per
// page load (reset on a full reload, which is what happens with Turbo Drive off).
let widgetInitialized = false;

// Initializes the La Suite "gaufre" v2 widget (loaded via the script tag rendered
// by LasuiteGaufreComponent) and themes its Shadow DOM panel for dark mode.
export default class extends Controller {
  static values = { config: Object };

  declare configValue: Record<string, string>;

  #themeObserver?: MutationObserver;
  #hostObserver?: MutationObserver;

  connect() {
    if (widgetInitialized) return;

    // There are two trigger buttons (mobile navbar + desktop toolbar), only one
    // visible per breakpoint. The widget is a single instance keyed by name and
    // toggles every bound button at once, so we bind it to a single button: the
    // one visible at load (mobile devices load at the mobile breakpoint).
    const button = BUTTON_IDS.map((id) => document.getElementById(id)).find(
      (el) => el && el.offsetParent !== null
    );
    if (!button) return;

    widgetInitialized = true;
    const queue = (window._lasuite_widget ||= []);
    queue.push([
      'lagaufre',
      'init',
      {
        ...this.configValue,
        buttonElement: button,
        position: () => {
          const rect = button.getBoundingClientRect();
          return {
            position: 'fixed',
            top: rect.bottom + 8,
            right: window.innerWidth - rect.right
          };
        }
      }
    ]);

    this.#themeWidgetPanel();
  }

  disconnect() {
    this.#themeObserver?.disconnect();
    this.#hostObserver?.disconnect();
  }

  // The widget panel lives in a Shadow DOM with a hardcoded light theme. Inject our
  // dark overrides into that shadow root and keep a `lasuite-dark` class on the host
  // in sync with the DSFR theme so the panel follows the app's scheme.
  #themeWidgetPanel() {
    const inject = (host: HTMLElement) => {
      const style = document.createElement('style');
      style.textContent = darkCss;
      host.shadowRoot?.appendChild(style);

      const sync = () =>
        host.classList.toggle(
          'lasuite-dark',
          document.documentElement.getAttribute('data-fr-theme') === 'dark'
        );
      sync();
      this.#themeObserver = new MutationObserver(sync);
      this.#themeObserver.observe(document.documentElement, {
        attributes: true,
        attributeFilter: ['data-fr-theme']
      });
    };

    // The host is created asynchronously once the widget script has loaded.
    const existing = document.getElementById(SHADOW_HOST_ID);
    if (existing?.shadowRoot) {
      inject(existing);
      return;
    }
    this.#hostObserver = new MutationObserver(() => {
      const host = document.getElementById(SHADOW_HOST_ID);
      if (host?.shadowRoot) {
        this.#hostObserver?.disconnect();
        inject(host);
      }
    });
    this.#hostObserver.observe(document.body, { childList: true });
  }
}
