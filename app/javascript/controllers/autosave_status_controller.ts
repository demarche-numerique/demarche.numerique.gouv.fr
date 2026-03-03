import { addClass, getConfig, removeClass, ResponseError } from '@utils';

import { ApplicationController } from './application_controller';

const {
  autosave: { status_visible_duration }
} = getConfig();
const AUTOSAVE_STATUS_VISIBLE_DURATION = status_visible_duration;

// This is a controller we attach to the status area in the main form. It
// coordinates autosave notifications.
//
export class AutosaveStatusController extends ApplicationController {
  static targets = ['idle', 'succeeded', 'failed'];

  declare readonly idleTarget: HTMLElement;
  declare readonly succeededTarget: HTMLElement;
  declare readonly failedTarget: HTMLElement;

  connect(): void {
    this.onGlobal('autosave:end', () => this.didSucceed());
    this.onGlobal<CustomEvent>('autosave:error', (event) =>
      this.didFail(event)
    );

    this.onGlobal('debounced:added', () => this.debouncedAdded());
    this.onGlobal('debounced:empty', () => this.debouncedEmpty());
  }

  private debouncedAdded() {
    const autosave = this.element as HTMLDivElement;
    removeClass(autosave, 'debounced-empty');
    addClass(autosave, 'debounced-added');
  }

  private debouncedEmpty() {
    const autosave = this.element as HTMLDivElement;
    addClass(autosave, 'debounced-empty');
    removeClass(autosave, 'debounced-added');
  }

  private didSucceed() {
    this.setState('succeeded');
    this.debounce(this.hideSucceededStatus, AUTOSAVE_STATUS_VISIBLE_DURATION);
  }

  private didFail(event: CustomEvent<{ error: ResponseError }>) {
    const error = event.detail.error;

    if (error.response?.status == 401) {
      // If we are unauthenticated, reload the page using a GET request.
      // This will allow Devise to properly redirect us to sign-in, and then back to this page.
      document.location.reload();
      return;
    }

    this.setState('failed');

    const shouldLogError = !error.response || error.response.status != 0; // ignore timeout errors
    if (shouldLogError) {
      this.logError(error);
    }
  }

  private setState(state: 'succeeded' | 'failed' | 'idle') {
    this.idleTarget.classList.toggle('fr-hidden', state !== 'idle');
    this.succeededTarget.classList.toggle('fr-hidden', state !== 'succeeded');
    this.failedTarget.classList.toggle('fr-hidden', state !== 'failed');
  }

  private hideSucceededStatus() {
    if (!this.succeededTarget.classList.contains('fr-hidden')) {
      this.setState('idle');
    }
  }

  private logError(error: ResponseError) {
    if (error && error.message) {
      console.error(error);
      this.globalDispatch('sentry:capture-exception', error);
    }
  }
}
