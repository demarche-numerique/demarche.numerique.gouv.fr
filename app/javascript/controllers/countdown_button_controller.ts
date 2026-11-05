import { Controller } from '@hotwired/stimulus';
import { cache } from '@hotwired/turbo';

const ANNOUNCEMENT_STEP = 30;

let lastTurboResponseAt = 0;

document.addEventListener('turbo:before-fetch-response', () => {
  lastTurboResponseAt = performance.now();
});

export class CountdownButtonController extends Controller {
  static targets = ['button', 'counter', 'status'];
  static values = {
    seconds: Number,
    counterOne: String,
    counterOther: String,
    announcementOne: String,
    announcementOther: String,
    available: String
  };

  declare readonly buttonTarget: HTMLButtonElement;
  declare readonly counterTarget: HTMLElement;
  declare readonly statusTarget: HTMLElement;
  declare readonly secondsValue: number;
  declare readonly counterOneValue: string;
  declare readonly counterOtherValue: string;
  declare readonly announcementOneValue: string;
  declare readonly announcementOtherValue: string;
  declare readonly availableValue: string;

  #deadline = 0;
  #announcedStep = 0;
  #timer?: ReturnType<typeof setInterval>;

  connect(): void {
    cache.exemptPageFromCache();
    if (this.secondsValue > 0) {
      this.#deadline =
        Date.now() + this.secondsValue * 1000 - this.#elapsedSinceResponse();
      this.#announcedStep = 0;
      this.#timer = setInterval(() => this.refresh(), 1000);
      this.#update(false);
    }
  }

  refresh(): void {
    this.#update(true);
  }

  #update(announce: boolean): void {
    if (this.#timer === undefined) {
      return;
    }
    const remaining = Math.ceil((this.#deadline - Date.now()) / 1000);
    if (remaining > 0) {
      this.buttonTarget.disabled = true;
      this.counterTarget.textContent = ` ${this.#inflect(
        remaining,
        this.counterOneValue,
        this.counterOtherValue
      )}`;
      const step = Math.ceil(remaining / ANNOUNCEMENT_STEP);
      if (announce && step !== this.#announcedStep) {
        this.#announcedStep = step;
        this.statusTarget.textContent = this.#inflect(
          remaining,
          this.announcementOneValue,
          this.announcementOtherValue
        );
      }
    } else {
      this.#stop();
      this.buttonTarget.disabled = false;
      this.counterTarget.textContent = '';
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

  #elapsedSinceResponse(): number {
    const [navigation] = performance.getEntriesByType(
      'navigation'
    ) as PerformanceNavigationTiming[];
    const responseAt = Math.max(
      navigation?.responseStart ?? 0,
      lastTurboResponseAt
    );
    return responseAt > 0 ? Math.max(0, performance.now() - responseAt) : 0;
  }

  #inflect(count: number, one: string, other: string): string {
    return count === 1 ? one : other.replace('#', String(count));
  }

  #stop(): void {
    clearInterval(this.#timer);
    this.#timer = undefined;
  }
}
