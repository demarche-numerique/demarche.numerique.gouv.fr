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
  static targets = [
    'idle',
    'succeeded',
    'failed',
    'serverErrorTemplate',
    'authErrorTemplate',
    'networkErrorTemplate'
  ];

  static values = {
    dossierId: Number,
    contactPath: String
  };

  declare readonly idleTarget: HTMLElement;
  declare readonly succeededTarget: HTMLElement;
  declare readonly failedTarget: HTMLElement;
  declare readonly serverErrorTemplateTarget: HTMLTemplateElement;
  declare readonly authErrorTemplateTarget: HTMLTemplateElement;
  declare readonly networkErrorTemplateTarget: HTMLTemplateElement;

  declare dossierIdValue: number;
  declare contactPathValue: string;

  private hasNotifiedError = false;

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
    this.hasNotifiedError = false;
    this.setState('succeeded');
    this.debounce(this.hideSucceededStatus, AUTOSAVE_STATUS_VISIBLE_DURATION);
  }

  private didFail(event: CustomEvent<{ error: ResponseError }>) {
    const error = event.detail.error;
    const eventId = this.captureError(error);

    this.renderErrorMessage(error, eventId);
    this.setState('failed');

    if (!this.hasNotifiedError) {
      this.hasNotifiedError = true;
      this.failedTarget.focus();
    }
  }

  private captureError(error: ResponseError): string | undefined {
    if (error.isNetworkError) return;

    console.error(error);
    return error.response?.headers.get('X-Request-Id') ?? undefined;
  }

  private renderErrorMessage(error: ResponseError, eventId?: string) {
    const template = this.templateForError(error);
    const content = template.content.cloneNode(true) as DocumentFragment;

    if (eventId) {
      const errorIdElement =
        content.querySelector<HTMLElement>('[data-error-id]');
      if (errorIdElement) {
        const format = errorIdElement.dataset.errorFormat ?? '(%{id})';
        errorIdElement.textContent = format.replace('%{id}', eventId);
      }
    }

    if (template === this.serverErrorTemplateTarget) {
      const link = content.querySelector<HTMLAnchorElement>('a');
      if (link) {
        link.href = this.buildContactUrl(eventId);
      }
    }

    this.failedTarget.innerHTML = '';
    this.failedTarget.appendChild(content);
  }

  private buildContactUrl(eventId?: string): string {
    const url = new URL(this.contactPathValue, window.location.origin);
    url.searchParams.set('dossier_id', String(this.dossierIdValue));
    url.searchParams.set('origin', 'autosave');
    if (eventId) {
      url.searchParams.set('error_id', eventId);
    }
    return url.pathname + url.search;
  }

  private templateForError(error: ResponseError): HTMLTemplateElement {
    if (error.isNetworkError) {
      return this.networkErrorTemplateTarget;
    } else if (this.isAuthError(error)) {
      return this.authErrorTemplateTarget;
    } else {
      return this.serverErrorTemplateTarget;
    }
  }

  private isAuthError(error: ResponseError): boolean {
    return error.response?.status == 401 || error.response?.status == 403;
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
}
