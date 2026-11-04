import { toggle } from '@utils';

import { ApplicationController } from './application_controller';

export class ExportTemplateKindController extends ApplicationController {
  static targets = ['kind', 'csvOnly'];

  declare readonly kindTargets: HTMLInputElement[];
  declare readonly csvOnlyTargets: HTMLElement[];

  connect() {
    this.update();
    this.on('change', () => this.update());
  }

  private update() {
    const kind = this.kindTargets.find((input) => input.checked)?.value;
    this.csvOnlyTargets.forEach((element) => toggle(element, kind === 'csv'));
  }
}
