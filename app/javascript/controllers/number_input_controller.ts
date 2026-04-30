import { isInputElement } from 'coldwired/utils';
import { ApplicationController } from './application_controller';

export class NumberInputController extends ApplicationController {
  connect() {
    this.onGlobal('wheel', (event) => {
      if (
        isInputElement(event.target) &&
        event.target.type == 'number' &&
        document.activeElement == event.target
      ) {
        event.preventDefault();
      }
    });
  }
}
