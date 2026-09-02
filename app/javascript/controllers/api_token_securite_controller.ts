import { ApplicationController } from './application_controller';

export class ApiTokenSecuriteController extends ApplicationController {
  static targets = [
    'continueButton',
    'networkFiltering',
    'customLifetime',
    'customLifetimeInput',
    'networks'
  ];

  declare readonly continueButtonTarget: HTMLButtonElement;
  declare readonly networkFilteringTarget: HTMLElement;
  declare readonly customLifetimeTarget: HTMLElement;
  declare readonly customLifetimeInputTarget: HTMLInputElement;
  declare readonly networksTarget: HTMLInputElement;

  connect() {
    this.setContinueButtonState();
  }

  showNetworkFiltering() {
    this.networkFilteringTarget.classList.remove('hidden');
    this.setContinueButtonState();
  }

  hideNetworkFiltering() {
    this.networkFilteringTarget.classList.add('hidden');
    this.setContinueButtonState();
  }

  showCustomLifetime() {
    this.customLifetimeTarget.classList.remove('hidden');
    this.setContinueButtonState();
  }

  hideCustomLifetime() {
    this.customLifetimeTarget.classList.add('hidden');
    this.setContinueButtonState();
  }

  setContinueButtonState() {
    if (this.lifetimeDefined()) {
      this.continueButtonTarget.disabled = false;
    } else {
      this.continueButtonTarget.disabled = true;
    }
  }

  lifetimeDefined() {
    const checked = this.element.querySelector<HTMLInputElement>(
      "[name='lifetime']:checked"
    );

    if (!checked) {
      return false;
    }

    // A preset lifetime is enough on its own; a custom one needs a date.
    if (checked.value != 'custom') {
      return true;
    }

    return this.customLifetimeInputTarget.value.trim() != '';
  }
}
