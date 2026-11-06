import { toggle } from '@utils';

import { ApplicationController } from './application_controller';

export class ExportTemplateKindController extends ApplicationController {
  static targets = ['kind', 'csvOnly', 'spreadsheetOnly'];

  declare readonly kindTargets: HTMLInputElement[];
  declare readonly csvOnlyTargets: HTMLElement[];
  declare readonly spreadsheetOnlyTargets: HTMLElement[];

  connect() {
    this.update();
    this.on('change', () => this.update());
  }

  private update() {
    const kind = this.kindTargets.find((input) => input.checked)?.value;
    this.csvOnlyTargets.forEach((element) => toggle(element, kind === 'csv'));
    this.spreadsheetOnlyTargets.forEach((element) =>
      toggle(element, kind !== 'csv')
    );
  }
}
