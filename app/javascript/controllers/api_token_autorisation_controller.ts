import { ApplicationController } from './application_controller';

export class ApiTokenAutorisationController extends ApplicationController {
  static targets = ['procedureSelectGroup', 'continueButton'];
  static values = { initialTargets: Boolean };

  declare readonly continueButtonTarget: HTMLButtonElement;
  declare readonly procedureSelectGroupTarget: HTMLElement;
  declare readonly initialTargetsValue: boolean;
  declare hasInitialTargets: boolean;

  connect() {
    const customTargets =
      this.element.querySelector("[value='custom']:checked") !== null;
    this.hasInitialTargets = this.initialTargetsValue;

    if (customTargets) {
      this.procedureSelectGroupTarget.classList.remove('hidden');
    }

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
    this.hasInitialTargets = false; // toute vérification suivante ignore l'état initial
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
      this.element.querySelectorAll<HTMLInputElement>("input[name='targets[]']")
    ).filter((input) => input.value.trim() !== '');

    return this.hasInitialTargets || selectedTargets.length > 0;
  }

  accessDefined() {
    return this.element.querySelectorAll("[name='access']:checked").length == 1;
  }
}
