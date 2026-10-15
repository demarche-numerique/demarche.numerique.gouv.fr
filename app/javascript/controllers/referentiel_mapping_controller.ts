import { ApplicationController } from './application_controller';
import { toggle } from '@utils';

export class ReferentielMappingController extends ApplicationController {
  static targets = ['input', 'enabledContent', 'disabledContent'];

  declare readonly enabledContentTarget: HTMLElement;
  declare readonly disabledContentTarget: HTMLElement;
  declare readonly checkboxTarget: HTMLInputElement;
  declare readonly inputTarget: HTMLInputElement;

  connect() {}

  // oxlint-disable-next-line @typescript-eslint/no-unused-vars
  onCheckboxChange(_event: Event) {
    toggle(this.enabledContentTarget);
    toggle(this.disabledContentTarget);
  }
}
