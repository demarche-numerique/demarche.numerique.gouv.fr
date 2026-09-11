import type { TurboSubmitEndEvent } from '@hotwired/turbo';

type SubmitButton = HTMLButtonElement | HTMLInputElement;

// Turbo's typings only expose `success` on the event detail; the response
// travels with it on successful submissions.
type SubmitEndDetail = TurboSubmitEndEvent['detail'] & {
  fetchResponse?: { redirected: boolean };
};

// Turbo disables the submitter only while the form request is in flight. When
// the response is a redirect, it re-enables the button before the redirected
// page is rendered, so a second click or an Enter keypress in that window
// submits the form again and cancels the pending visit. Keep the form locked
// until the render settles (or the visit fails).
//
// Only redirects qualify: a response rendered in place (a turbo stream, a 422
// re-render) never triggers a page load that would unlock the form again.
export class SubmitRenderGuard {
  #forms = new Set<HTMLFormElement>();
  #buttons = new Set<SubmitButton>();

  submitEnded(event: TurboSubmitEndEvent): void {
    const { formSubmission, success, fetchResponse } =
      event.detail as SubmitEndDetail;
    if (!success || !fetchResponse?.redirected) {
      return;
    }

    const form = formSubmission.formElement;
    form.addEventListener('submit', preventSubmit, { capture: true });
    this.#forms.add(form);

    for (const button of submitButtons(form)) {
      if (!button.disabled) {
        button.disabled = true;
        this.#buttons.add(button);
      }
    }
  }

  rendered(): void {
    for (const form of this.#forms) {
      form.removeEventListener('submit', preventSubmit, { capture: true });
    }
    for (const button of this.#buttons) {
      button.disabled = false;
    }
    this.#forms.clear();
    this.#buttons.clear();
  }
}

function preventSubmit(event: Event): void {
  event.preventDefault();
  event.stopImmediatePropagation();
}

// `form.elements` includes the buttons associated through a `form` attribute.
function submitButtons(form: HTMLFormElement): SubmitButton[] {
  return Array.from(form.elements).filter(
    (element): element is SubmitButton =>
      (element instanceof HTMLButtonElement ||
        element instanceof HTMLInputElement) &&
      element.type == 'submit'
  );
}
