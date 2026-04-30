import { ApplicationController } from './application_controller';

export class ProcedureStickyTitleController extends ApplicationController {
  private observer?: IntersectionObserver;

  connect(): void {
    const breadcrumb = document.querySelector<HTMLElement>('.fr-breadcrumb');
    if (!breadcrumb) return;

    this.observer = new IntersectionObserver(
      (entries) => {
        const entry = entries[0];
        if (!entry) return;
        this.element.classList.toggle('visible', !entry.isIntersecting);
      },
      { rootMargin: '0px', threshold: 0 }
    );

    this.observer.observe(breadcrumb);
  }

  disconnect(): void {
    this.observer?.disconnect();
    this.observer = undefined;
  }
}
