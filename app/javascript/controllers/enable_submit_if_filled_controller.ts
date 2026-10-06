import { Controller } from '@hotwired/stimulus';

export class EnableSubmitIfFilledController extends Controller {
  static targets = ['submit', 'input'];

  declare readonly submitTarget: HTMLButtonElement;
  declare readonly inputTargets: HTMLInputElement[];

  // Several input targets when a combobox is the input: it renders its value in
  // hidden inputs, re-rendered by React, one per selected item for a multiple
  // combobox, a single one (empty when nothing is selected) otherwise.
  fill() {
    this.submitTarget.disabled = !this.inputTargets.some(
      (input) => input.value.trim() != ''
    );
  }
}
