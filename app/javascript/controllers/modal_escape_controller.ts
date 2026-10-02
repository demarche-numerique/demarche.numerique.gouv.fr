import { ApplicationController } from './application_controller';

declare const window: Window &
  typeof globalThis & {
    dsfr: (element: Element) => {
      modal: { conceal: () => void; focus: () => void };
    };
  };

export class ModalEscapeController extends ApplicationController {
  close() {
    const modal = window.dsfr(this.element).modal;
    modal.conceal();
    modal.focus();
  }
}
