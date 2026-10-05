import { Controller } from '@hotwired/stimulus';

export class ToggleRestrictionController extends Controller {
  static targets = ['fullAccessBlock', 'restrictedBlock'];

  declare readonly fullAccessBlockTarget: HTMLElement;
  declare readonly restrictedBlockTarget: HTMLElement;

  reveal() {
    this.fullAccessBlockTarget.classList.add('hidden');
    this.restrictedBlockTarget.classList.remove('hidden');
  }
}
