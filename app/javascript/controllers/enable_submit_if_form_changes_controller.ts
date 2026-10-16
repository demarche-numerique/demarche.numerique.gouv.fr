import { ApplicationController } from './application_controller';

export class EnableSubmitIfFormChangesController extends ApplicationController {
  static targets = ['submitButton'];

  declare readonly submitButtonTarget: HTMLButtonElement;

  private initialFormData: string = '';

  connect() {
    this.initialFormData = this.formData();
  }

  onFormChange() {
    const currentFormData = this.formData();
    this.submitButtonTarget.disabled = currentFormData === this.initialFormData;
  }

  private formData(): string {
    const form = this.element as HTMLFormElement;
    const formData = new FormData(form);

    const ignoredKeys = ['authenticity_token', '_method'];

    const entries = Array.from(formData.entries())
      .filter(([key]) => !ignoredKeys.includes(key))
      .sort(([a], [b]) => a.localeCompare(b));

    return JSON.stringify(entries);
  }
}
