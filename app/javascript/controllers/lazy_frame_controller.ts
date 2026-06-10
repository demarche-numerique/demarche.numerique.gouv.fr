import { ApplicationController } from './application_controller';

interface HTMLTurboFrameElement extends HTMLElement {
  src: string | null;
}

// Loads a turbo-frame on demand (e.g. when a button is clicked) instead of
// eagerly on page load. Used for the filter panel: its counts are expensive,
// so the frame is only fetched when the user opens the drawer. The src is
// rebuilt from the current location each time, so reopening the drawer after a
// reset or an applied filter reflects the active filters instead of a stale
// state. While the drawer stays open, the live-preview (filter_preview_controller)
// keeps the counts fresh on every change.
export default class LazyFrameController extends ApplicationController {
  static values = { frameId: String, src: String };

  declare readonly frameIdValue: string;
  declare readonly srcValue: string;

  load(): void {
    const frame = document.getElementById(
      this.frameIdValue
    ) as HTMLTurboFrameElement | null;

    if (!frame) return;

    const url = new URL(this.srcValue, window.location.origin);
    url.search = window.location.search;
    url.searchParams.set('filter_panel', '1');
    const src = url.toString();

    // Reflect the current filters on the (stale) controls right away so the
    // drawer opens in the correct state instead of flashing the previous
    // selection while the frame reloads in the background.
    this.syncCheckedState(frame, url.searchParams);

    // Already showing the current filter state: nothing to reload.
    if (frame.getAttribute('src') === src) return;

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

    // The freshly rendered markup can be re-checked by the browser's form
    // restoration (attribute unchecked but live property true); realign it.
    frame.addEventListener(
      'turbo:frame-render',
      () => this.syncCheckedState(frame, url.searchParams),
      { once: true }
    );

    // A loaded turbo-frame is marked `complete` and ignores a plain `src`
    // change, so the stale (filtered) panel would stick. Clear `complete`
    // first to force Turbo to refetch with the current filters.
    frame.removeAttribute('complete');
    frame.src = src;
  }

  private syncCheckedState(
    frame: HTMLTurboFrameElement,
    params: URLSearchParams
  ): void {
    // Realign each checkbox with the URL it was rendered from, reading the
    // input's own name (e.g. `state[]`, `alert[]`, `shared_with_me`) so this
    // never drifts from the server-side form.
    frame
      .querySelectorAll<HTMLInputElement>('input[type="checkbox"]')
      .forEach((input) => {
        input.checked = params.getAll(input.name).includes(input.value);
      });
  }
}
