import { ApplicationController } from './application_controller';

// Asks for confirmation before a plain link is followed or a native form is
// submitted. Elements that Turbo intercepts use `data-turbo-confirm` instead.
export class ConfirmController extends ApplicationController {
  static values = { message: String };

  declare readonly messageValue: string;

  ask(event: Event) {
    if (!window.confirm(this.messageValue)) {
      event.preventDefault();
      event.stopImmediatePropagation();
    }
  }
}
