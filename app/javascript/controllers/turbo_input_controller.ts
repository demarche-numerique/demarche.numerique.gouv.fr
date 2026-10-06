import { httpRequest } from '@utils';

import { ApplicationController } from './application_controller';

export class TurboInputController extends ApplicationController {
  static values = {
    url: String,
    loadOnConnect: { type: Boolean, default: false }
  };

  declare readonly urlValue: string;
  declare readonly loadOnConnectValue: boolean;

  connect(): void {
    this.on('input', () => this.debounce(this.load, 200));
    if (this.loadOnConnectValue) {
      this.load();
    }
  }

  private load(): void {
    const target = this.element as HTMLInputElement;
    const url = new URL(this.urlValue, document.baseURI);
    const formData = new FormData();
    formData.append(target.name, target.value);
    httpRequest(url.toString(), { method: 'post', body: formData })
      .turbo()
      .catch(() => null);
  }
}
