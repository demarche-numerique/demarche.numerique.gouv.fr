import { Controller } from '@hotwired/stimulus';

export class EnableSubmitIfCheckedController extends Controller {
  static targets = ['submit'];
  declare readonly submitTarget: HTMLButtonElement;

  click() {
    if (
      this.element.querySelectorAll('input[type="radio"]:checked').length > 0 ||
      this.element.querySelectorAll('input[type="checkbox"]:checked').length > 0
    ) {
      this.submitTarget.disabled = false;
    } else {
      this.submitTarget.disabled = true;
    }
  }
}
