import { isFormInputElement, matchInputElement } from 'coldwired/utils';

import { ApplicationController } from './application_controller';

const AUTOSUBMIT_DATE_DEBOUNCE_DELAY = 5000;
const AUTOSUBMIT_EVENTS = ['input', 'change', 'blur'];

export class AutosubmitController extends ApplicationController {
  static targets = ['submitter', 'input'];
  static values = {
    debounceDelay: { type: Number, default: 500 }
  };

  declare readonly submitterTarget: HTMLButtonElement | HTMLInputElement;
  declare readonly hasSubmitterTarget: boolean;
  declare readonly inputTargets: HTMLInputElement[];
  declare readonly debounceDelayValue: number;

  #dateTimeChangedInputs = new WeakSet<HTMLElement>();

  connect() {
    this.on('input', (event) => this.onInput(event));
    this.on('change', (event) => this.onChange(event));
    this.on('blur', (event) => this.onBlur(event));
  }

  private onChange(event: Event) {
    const target = this.findTargetElement(event);

    matchInputElement(target, {
      date: (target) => {
        if (target.value.trim() == '' || !isNaN(Date.parse(target.value))) {
          this.#dateTimeChangedInputs.add(target);
          this.debounce(this.submit, AUTOSUBMIT_DATE_DEBOUNCE_DELAY);
        } else {
          this.#dateTimeChangedInputs.delete(target);
          this.cancelDebounce(this.submit);
        }
      },
      text: () => this.submitNow(),
      changeable: () => this.submitNow(),
      hidden: () => this.submitNow()
    });
  }

  private onInput(event: Event) {
    const target = this.findTargetElement(event);

    matchInputElement(target, {
      date: () => {},
      inputable: () => this.debounce(this.submit, this.debounceDelayValue),
      hidden: () => this.debounce(this.submit, this.debounceDelayValue)
    });
  }

  private onBlur(event: Event) {
    const target = this.findTargetElement(event);
    if (!target) return;

    matchInputElement(target, {
      date: () => {
        Promise.resolve().then(() => {
          if (this.#dateTimeChangedInputs.has(target)) {
            this.submitNow();
          }
        });
      }
    });
  }

  private findTargetElement(event: Event) {
    const target = event.target;

    if (
      !isFormInputElement(target) ||
      this.preventAutosubmit(target, event.type)
    ) {
      return null;
    }
    return target;
  }

  private preventAutosubmit(
    target: HTMLElement & { disabled?: boolean } & { value?: string },
    type: string
  ) {
    if (target.disabled) {
      return true;
    }
    if (
      this.inputTargets.length > 0 &&
      !this.inputTargets.includes(target as HTMLInputElement)
    ) {
      return true;
    }
    if (
      Boolean(target.getAttribute('data-no-autosubmit-on-empty')) &&
      target.value == ''
    ) {
      return true;
    }

    const noAutosubmit = this.parseNoAutosubmit(
      target.getAttribute('data-no-autosubmit')
    );
    if (Array.isArray(noAutosubmit)) {
      return noAutosubmit.includes(type);
    }
    return noAutosubmit;
  }

  private parseNoAutosubmit(value?: string | null): boolean | string[] {
    if (value == null) {
      return false;
    }
    const eventTypes = value
      .split(' ')
      .map((token) => token.trim())
      .filter((eventType) => AUTOSUBMIT_EVENTS.includes(eventType));
    return eventTypes.length == 0 ? true : eventTypes;
  }

  private submitNow() {
    this.cancelDebounce(this.submit);
    this.submit();
  }

  private submit() {
    const submitter = this.hasSubmitterTarget ? this.submitterTarget : null;
    const form =
      submitter?.form ?? this.element.closest<HTMLFormElement>('form');

    // Safari does not support "formaction" attribute on submitter passed to requestSubmit :(
    if (submitter && navigator.userAgent.indexOf('Safari') > -1) {
      submitter.click();
    } else {
      form?.requestSubmit(submitter);
    }
  }
}
