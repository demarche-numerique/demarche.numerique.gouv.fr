import { ApplicationController } from './application_controller';

export class ElementRemoveController extends ApplicationController {
  remove() {
    this.element.remove();
  }
}
