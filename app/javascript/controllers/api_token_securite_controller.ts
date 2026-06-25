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
    if (this.networkDefined() && this.lifetimeDefined()) {
      this.continueButtonTarget.disabled = false;
    } else {
      this.continueButtonTarget.disabled = true;
    }
  }

  networkDefined() {
    if (
      this.element.querySelectorAll(
        "[name='networkFiltering'][value='autoAssign']:checked"
      ).length > 0
    ) {
      return true;
    }

    if (
      this.element.querySelectorAll(
        "[name='networkFiltering'][value='customNetworks']:checked"
      ).length > 0 &&
      this.networksTarget.value.trim() != ''
    ) {
      return true;
    }

    return false;
  }

  lifetimeDefined() {
    if (
      this.element.querySelectorAll(
        "[name='lifetime'][value='oneWeek']:checked"
      ).length > 0
    ) {
      return true;
    }

    if (
      this.element.querySelectorAll(
        "[name='lifetime'][value='infinite']:checked"
      ).length > 0
    ) {
      return true;
    }

    if (
      this.element.querySelectorAll("[name='lifetime'][value='custom']:checked")
        .length > 0 &&
      this.customLifetimeInputTarget.value.trim() != ''
    ) {
      return true;
    }

    return false;
  }
}
