import { ApplicationController } from './application_controller';

declare const window: Window &
  typeof globalThis & {
    dsfr?: (el: HTMLElement) => {
      collapse: { disclose: () => void; conceal: () => void };
    };
  };

export class RepetitionToggleAllController extends ApplicationController {
  static targets = ['icon', 'text', 'rowsContainer', 'button'];
  static values = {
    expandedText: String,
    collapsedText: String
  };

  declare readonly iconTarget: HTMLElement;
  declare readonly textTarget: HTMLElement;
  declare readonly rowsContainerTarget: HTMLElement;
  declare readonly hasButtonTarget: boolean;
  declare readonly buttonTarget: HTMLButtonElement;
  declare expandedTextValue: string;
  declare collapsedTextValue: string;

  private mutationObserver?: MutationObserver;

  connect() {
    if (!this.hasButtonTarget) {
      return;
    }

    this.updateButtonState();
    // Listen to accordion changes to update button state
    this.rowsContainerTarget.addEventListener(
      'click',
      this.handleAccordionClick,
      true
    );

    // Watch for DOM changes (e.g., when rows are added via Turbo Stream)
    this.mutationObserver = new MutationObserver(() => {
      // Update button state after a delay to allow DSFR to initialize new accordions
      setTimeout(() => {
        this.updateButtonState();
      }, 200);
    });

    this.mutationObserver.observe(this.rowsContainerTarget, {
      childList: true,
      subtree: true
    });
  }

  disconnect() {
    super.disconnect();
    if (!this.hasButtonTarget) {
      return;
    }

    this.rowsContainerTarget.removeEventListener(
      'click',
      this.handleAccordionClick,
      true
    );
    this.mutationObserver?.disconnect();
  }

  toggleAll(event: Event) {
    event.preventDefault();
    const allExpanded = this.areAllExpanded();
    const shouldExpand = !allExpanded;

    // Find all collapse elements (fr-collapse) in the container
    const collapseElements =
      this.rowsContainerTarget.querySelectorAll<HTMLElement>('.fr-collapse');

    if (!window.dsfr) {
      return;
    }

    collapseElements.forEach((collapseElement) => {
      const dsfrInstance = window.dsfr?.(collapseElement);
      if (dsfrInstance?.collapse) {
        if (shouldExpand) {
          dsfrInstance.collapse.disclose();
        } else {
          dsfrInstance.collapse.conceal();
        }
      }
    });

    // Update button state after a short delay to allow DSFR to update
    setTimeout(() => {
      this.updateButtonState();
    }, 100);
  }

  // An arrow function keeps the same reference for removeEventListener.
  private handleAccordionClick = (event: Event) => {
    // Check if the click was on an accordion button
    const target = event.target as HTMLElement;
    if (target.closest('.fr-accordion__btn')) {
      // Update button state after accordion state changes
      setTimeout(() => {
        this.updateButtonState();
      }, 100);
    }
  };

  private areAllExpanded(): boolean {
    const accordionButtons =
      this.rowsContainerTarget.querySelectorAll<HTMLButtonElement>(
        '.fr-accordion__btn'
      );

    if (accordionButtons.length === 0) {
      return false;
    }

    return Array.from(accordionButtons).every(
      (button) => button.getAttribute('aria-expanded') === 'true'
    );
  }

  private updateButtonState() {
    const allExpanded = this.areAllExpanded();

    // Update icon
    if (allExpanded) {
      // Change icon to up arrow (replier)
      this.iconTarget.className = 'fr-icon-arrow-up-double-line';
    } else {
      // Change icon to down arrow (déplier)
      this.iconTarget.className = 'fr-icon-arrow-down-double-line';
    }

    // Update button text
    this.textTarget.textContent = allExpanded
      ? this.expandedTextValue
      : this.collapsedTextValue;

    // Update aria-expanded for accessibility
    this.buttonTarget.setAttribute('aria-expanded', allExpanded.toString());
  }
}
