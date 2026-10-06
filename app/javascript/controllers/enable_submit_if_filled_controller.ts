import { Controller } from '@hotwired/stimulus';

export class EnableSubmitIfFilledController extends Controller {
  static targets = ['submit', 'input'];

  declare readonly submitTarget: HTMLButtonElement;
  declare readonly inputTarget: HTMLInputElement;
  declare readonly inputTargets: HTMLInputElement[];

  fill() {
    if (this.inputTarget.value.trim() != '') {
      this.submitTarget.disabled = false;
    } else {
      this.submitTarget.disabled = true;
    }
  }

  // A combobox renders its value in hidden inputs, re-rendered by React: one per
  // selected item for a multiple combobox, a single one (empty when nothing is
  // selected) otherwise.
  fillCombobox() {
    this.submitTarget.disabled = !this.inputTargets.some(
      (input) => input.value.trim() != ''
    );
  }
}
