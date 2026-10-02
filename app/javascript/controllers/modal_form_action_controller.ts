import type { ActionEvent } from '@hotwired/stimulus';
import invariant from 'tiny-invariant';

import { ApplicationController } from './application_controller';

export class ModalFormActionController extends ApplicationController {
  set(event: ActionEvent) {
    const modalId = this.element.getAttribute('aria-controls');
    invariant(modalId, 'aria-controls is required');
    const form = document.getElementById(modalId)?.querySelector('form');
    invariant(form, `a form is required in #${modalId}`);
    form.action = event.params.url;
  }
}
