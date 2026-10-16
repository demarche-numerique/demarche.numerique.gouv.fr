import { ApplicationController } from './application_controller';

export class RepetitionLimitsController extends ApplicationController {
  static values = { errorId: String };

  declare readonly errorIdValue: string;

  clear(event: CustomEvent<{ error_id: string } | null>) {
    if (event.detail?.error_id !== this.errorIdValue) {
      return;
    }

    this.element.closest('fieldset')?.classList.remove('fr-fieldset--error');
    document.getElementById(this.errorIdValue)?.replaceChildren();
  }
}
