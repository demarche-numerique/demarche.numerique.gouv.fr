import { ApplicationController } from './application_controller';

export class ApiTokenAutorisationController extends ApplicationController {
  static targets = [
    'procedures',
    'procedureSelect',
    'procedureSelectGroup',
    'continueButton'
  ];

  declare readonly continueButtonTarget: HTMLButtonElement;
  declare readonly procedureSelectTarget: HTMLSelectElement;
  declare readonly procedureSelectGroupTarget: HTMLElement;
  declare readonly proceduresTarget: HTMLElement;

  connect() {
    const urlSearchParams = new URLSearchParams(window.location.search);
    const targetIds = urlSearchParams.getAll('targets[]');
    const customTargets = urlSearchParams.get('target') == 'custom';

    this.setupProceduresTarget(targetIds);

    if (customTargets && targetIds.length > 0) {
      this.showProcedureSelectGroup();
    }

    this.setContinueButtonState();
  }

  setupProceduresTarget(targetIds: string[]) {
    const options = Array.from(this.procedureSelectTarget.options);

    targetIds
      .map((id) => options.find((x) => x.value == id))
      .forEach((option) => option && this.addProcedureToSelect(option));
  }

  addProcedure(e: Event) {
    e.preventDefault();
    const selectedOption = this.procedureSelectTarget.selectedOptions[0];
    this.addProcedureToSelect(selectedOption);

    this.setContinueButtonState();
  }

  addProcedureToSelect(option: HTMLOptionElement) {
    const li = document.createElement('li');
    li.className = 'flex align-center';
    li.append(option.text);

    const button = document.createElement('button');
    button.className =
      'fr-btn fr-icon-delete-line fr-btn--tertiary-no-outline fr-ml-1w';
    button.dataset.action = 'click->api-token-autorisation#deleteProcedure';
    li.append(button);

    const input = document.createElement('input');
    input.type = 'hidden';
    input.name = '[targets][]';
    input.value = option.value;
    li.append(input);

    this.proceduresTarget.append(li);
  }

  deleteProcedure(e: Event) {
    e.preventDefault();
    const target = e.target as HTMLElement;
    target.closest('li')?.remove();
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
    if (this.targetDefined() && this.accessDefined()) {
      this.continueButtonTarget.disabled = false;
    } else {
      this.continueButtonTarget.disabled = true;
    }
  }

  targetDefined() {
    if (this.element.querySelectorAll("[value='all']:checked").length > 0) {
      return true;
    }

    if (
      this.element.querySelectorAll("[value='custom']:checked").length > 0 &&
      this.proceduresTarget.children.length > 0
    ) {
      return true;
    }

    return false;
  }

  accessDefined() {
    return this.element.querySelectorAll("[name='access']:checked").length == 1;
  }
}
