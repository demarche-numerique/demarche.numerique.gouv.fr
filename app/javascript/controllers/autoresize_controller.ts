import { attach } from '@frsource/autoresize-textarea';
import { isTextAreaElement } from 'coldwired/utils';
import { ApplicationController } from './application_controller';

export class AutoresizeController extends ApplicationController {
  declare observer: IntersectionObserver;

  #detach?: () => void;
  connect(): void {
    if (isTextAreaElement(this.element)) {
      this.element.classList.add('resize-none');
      this.observer = new IntersectionObserver(this.onIntersect.bind(this), {
        threshold: [0]
      });
      this.observer.observe(this.element);
    }
  }

  onIntersect(entries: IntersectionObserverEntry[]): void {
    const visible = entries[0].isIntersecting == true;

    if (visible) {
      this.#detach = attach(this.element as HTMLTextAreaElement)?.detach;
      this.observer.unobserve(this.element);
    }
  }

  disconnect(): void {
    this.#detach?.();
    this.observer.unobserve(this.element);
    this.element.classList.remove('resize-none');
  }
}
