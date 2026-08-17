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
    // visible per breakpoint. The widget binds a single, permanent buttonElement
    // (no re-bind command), so handing it one button leaves the other inert after
    // a resize across the breakpoint. Instead we omit buttonElement and wire both
    // buttons ourselves, anchoring the panel to whichever one is currently visible.
    const buttons = BUTTON_IDS.map((id) => document.getElementById(id)).filter(
      (el): el is HTMLElement => el != null
    );
    if (buttons.length === 0) return;

    widgetInitialized = true;

    // Only one button is visible per breakpoint, and the user can only interact
    // with the visible one, so we always resolve "the button" at call time rather
    // than caching a reference. This keeps the panel anchored to (and focus
    // restored to) the right button even after the window is resized across the
    // breakpoint while the page stays loaded.
    const triggerButton = () =>
      buttons.find((el) => el.offsetParent !== null) ?? buttons[0];

    const queue = (window._lasuite_widget ||= []);
    queue.push([
      'lagaufre',
      'init',
      {
        ...this.configValue,
        position: () => {
          const rect = triggerButton().getBoundingClientRect();
          return {
            position: 'fixed',
            top: rect.bottom + 8,
            right: window.innerWidth - rect.right
          };
        }
      }
    ]);

    for (const button of buttons) {
      button.addEventListener('click', () =>
        queue.push(['lagaufre', 'toggle'])
      );
    }

    // Without a buttonElement the widget no longer manages aria-expanded or
    // restores focus on close, so we mirror its open/close events onto the visible
    // button. Restoring focus on close is the accessibility fix this migration is
    // about. The `isOpen` guard ignores any spurious close dispatched before the
    // panel was ever opened (e.g. on init).
    let isOpen = false;
    document.addEventListener('lasuite-widget-lagaufre-opened', () => {
      isOpen = true;
      triggerButton().setAttribute('aria-expanded', 'true');
    });
    document.addEventListener('lasuite-widget-lagaufre-closed', () => {
      if (!isOpen) return;
      isOpen = false;
      const button = triggerButton();
      button.setAttribute('aria-expanded', 'false');
      button.focus();
    });

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
