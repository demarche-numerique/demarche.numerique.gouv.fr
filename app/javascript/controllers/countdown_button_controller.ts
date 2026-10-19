import { Controller } from '@hotwired/stimulus';
import { cache } from '@hotwired/turbo';

export class CountdownButtonController extends Controller {
  static targets = ['button', 'status'];
  static values = {
    seconds: Number,
    one: String,
    other: String,
    label: String,
    available: String
  };

  declare readonly buttonTarget: HTMLButtonElement;
  declare readonly statusTarget: HTMLElement;
  declare readonly secondsValue: number;
  declare readonly oneValue: string;
  declare readonly otherValue: string;
  declare readonly labelValue: string;
  declare readonly availableValue: string;

  #deadline = 0;
  #timer?: ReturnType<typeof setInterval>;

  connect(): void {
    cache.exemptPageFromCache();
    if (this.secondsValue > 0) {
      this.#deadline = Date.now() + this.secondsValue * 1000;
      this.#timer = setInterval(() => this.refresh(), 1000);
      this.refresh();
    }
  }

  refresh(): void {
    if (this.#timer === undefined) {
      return;
    }
    const button = this.buttonTarget;
    const remaining = Math.ceil((this.#deadline - Date.now()) / 1000);
    if (remaining > 0) {
      button.disabled = true;
      button.textContent =
        remaining === 1
          ? this.oneValue
          : this.otherValue.replace('#', String(remaining));
    } else {
      this.#stop();
      button.disabled = false;
      button.textContent = this.labelValue;
      this.statusTarget.textContent = this.availableValue;
    }
  }

  restore(event: PageTransitionEvent): void {
    if (event.persisted) {
      this.reloadPage();
    }
  }

  reloadPage(): void {
    window.location.reload();
  }

  disconnect(): void {
    this.#stop();
  }

  #stop(): void {
    clearInterval(this.#timer);
    this.#timer = undefined;
  }
}
