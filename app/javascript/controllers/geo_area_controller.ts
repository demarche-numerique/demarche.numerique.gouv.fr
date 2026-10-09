import { ApplicationController } from './application_controller';

export class GeoAreaController extends ApplicationController {
  static values = {
    id: String
  };
  static targets = ['description'];

  declare readonly idValue: string;
  declare readonly descriptionTarget: HTMLInputElement;

  onFocus() {
    this.globalDispatch('map:feature:focus', { id: this.idValue });
  }

  onClick(event: MouseEvent) {
    event.preventDefault();
    this.globalDispatch('map:feature:focus', { id: this.idValue });
  }

  onInput() {
    this.debounce(this.updateDescription, 500);
  }

  private updateDescription(): void {
    this.globalDispatch('map:feature:update', {
      id: this.idValue,
      properties: { description: this.descriptionTarget.value.trim() }
    });
  }
}
