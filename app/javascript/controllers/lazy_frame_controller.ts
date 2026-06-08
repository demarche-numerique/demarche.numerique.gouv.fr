import { ApplicationController } from './application_controller';

interface HTMLTurboFrameElement extends HTMLElement {
  src: string | null;
}

// Loads a turbo-frame on demand (e.g. when a button is clicked) instead of
// eagerly on page load. Used for the filter panel: its counts are expensive,
// so the frame is only fetched the first time the user opens the drawer.
// Loading once is intentional — while the drawer is open, the live-preview
// (filter_preview_controller) keeps the counts fresh on every change.
export default class LazyFrameController extends ApplicationController {
  static values = { frameId: String, src: String };

  declare readonly frameIdValue: string;
  declare readonly srcValue: string;

  load(): void {
    const frame = document.getElementById(
      this.frameIdValue
    ) as HTMLTurboFrameElement | null;

    if (!frame || frame.getAttribute('src')) return;

    // If the session expired, the response won't contain the expected frame.
    // Reload so authenticate_user! replays on the current URL instead of
    // leaving the drawer stuck on its loading placeholder.
    frame.addEventListener(
      'turbo:frame-missing',
      (event) => {
        event.preventDefault();
        window.location.reload();
      },
      { once: true }
    );

    frame.src = this.srcValue;
  }
}
