import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLFormElement> {
  static targets = ['submit'];
  declare readonly submitTarget: HTMLButtonElement;

  connect() {
    this.toggleSubmit();
    this.element.addEventListener('change', () => this.toggleSubmit());
    this.element.addEventListener('input', () => this.toggleSubmit());
  }

  toggleSubmit() {
    const inputs = this.element.querySelectorAll<HTMLInputElement>(
      'input[type="hidden"][name^="presentations["]'
    );
    const hasSelection = Array.from(inputs).some((i) => i.value !== '');
    this.submitTarget.disabled = !hasSelection;
  }
}
