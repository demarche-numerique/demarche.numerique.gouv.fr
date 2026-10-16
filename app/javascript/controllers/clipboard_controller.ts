import { Controller } from '@hotwired/stimulus';

const SUCCESS_MESSAGE_TIMEOUT = 1000;

export class ClipboardController extends Controller {
  static values = { text: String };
  static targets = ['success', 'toHide'];

  declare readonly textValue: string;
  declare readonly successTarget: HTMLElement;
  declare readonly toHideTarget: HTMLElement;
  declare readonly hasSuccessTarget: boolean;
  declare readonly hasToHideTarget: boolean;

  #timer?: ReturnType<typeof setTimeout>;

  connect(): void {
    // some extensions or browsers block clipboard
    if (!navigator.clipboard) {
      if (this.hasToHideTarget) {
        this.toHideTarget.classList.add('hidden');
      } else {
        this.element.classList.add('hidden');
      }
    }
  }

  disconnect(): void {
    clearTimeout(this.#timer);
  }

  copy() {
    void navigator.clipboard
      .writeText(this.textValue)
      .then(() => this.displayCopyConfirmation());
  }

  private displayCopyConfirmation() {
    if (this.hasToHideTarget) {
      this.toHideTarget.classList.add('hidden');
    }
    if (this.hasSuccessTarget) {
      this.successTarget.classList.remove('hidden');
    }

    clearTimeout(this.#timer);

    this.#timer = setTimeout(() => {
      if (this.hasSuccessTarget) {
        this.successTarget.classList.add('hidden');
      }
      if (this.hasToHideTarget) {
        this.toHideTarget.classList.remove('hidden');
      }
    }, SUCCESS_MESSAGE_TIMEOUT);
  }
}
