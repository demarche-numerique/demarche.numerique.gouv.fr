import { ApplicationController } from './application_controller';

export class RepetitionLimitsController extends ApplicationController {
  static targets = ['row'];
  static values = { min: Number, errorId: String };

  declare readonly rowTargets: HTMLElement[];
  declare readonly minValue: number;
  declare readonly errorIdValue: string;

  #connected = false;

  connect() {
    this.#connected = true;
  }

  disconnect() {
    this.#connected = false;
  }

  rowTargetConnected() {
    if (!this.#connected || this.rowTargets.length < this.minValue) {
      return;
    }

    this.element.closest('fieldset')?.classList.remove('fr-fieldset--error');
    document.getElementById(this.errorIdValue)?.replaceChildren();
  }
}
