import { Controller } from '@hotwired/stimulus';
import { enable, disable } from '@utils';

export class EnableSubmitIfUploadedController extends Controller {
  static targets = ['submit', 'input'];

  declare readonly submitTarget: HTMLButtonElement;
  declare readonly inputTarget: HTMLInputElement;

  upload() {
    this.inputTarget.addEventListener('change', () => {
      if (this.inputTarget.files && this.inputTarget.files.length > 0) {
        enable(this.submitTarget);
      } else {
        disable(this.submitTarget);
      }
    });
  }
}
