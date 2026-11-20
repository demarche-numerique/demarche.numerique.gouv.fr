import { ApplicationController } from './application_controller';

export class ApiTokenAutorisationController extends ApplicationController {
  static targets = ['procedureSelectGroup', 'continueButton'];
  static values = { initialTargets: Boolean };

  declare readonly continueButtonTarget: HTMLButtonElement;
  declare readonly procedureSelectGroupTarget: HTMLElement;
  declare initialTargetsValue: boolean;

  connect() {
    this.setContinueButtonState();
  }

  showProcedureSelectGroup() {
    this.procedureSelectGroupTarget.classList.remove('hidden');
    this.setContinueButtonState();
  }

  hideProcedureSelectGroup() {
    this.procedureSelectGroupTarget.classList.add('hidden');
    this.setContinueButtonState();
  }

  setContinueButtonState() {
    this.continueButtonTarget.disabled = !(
      this.targetDefined() && this.accessDefined()
    );
    this.initialTargetsValue = false; // toute vérification suivante ignore l'état initial
  }

  targetDefined() {
    if (this.element.querySelectorAll("[value='all']:checked").length > 0) {
      return true;
    }

    const hasCustomSelected =
      this.element.querySelectorAll("[value='custom']:checked").length > 0;
    if (!hasCustomSelected) {
      return false;
    }

    const selectedTargets = Array.from(
      this.element.querySelectorAll<HTMLInputElement>(
        "input[name='api_token_form[procedure_ids][]']"
      )
    ).filter((input) => input.value.trim() !== '');

    return this.initialTargetsValue || selectedTargets.length > 0;
  }

  accessDefined() {
    return (
      this.element.querySelectorAll("[name='api_token_form[access]']:checked")
        .length == 1
    );
  }
}
