import { toggle } from '@utils';
import { ApplicationController } from './application_controller';

// Warns that saving a new declarative setting deletes the customized accusé de
// réception. Compared to the saved value, not toggled: coming back to it hides
// the warning again.
export class DeclarativeSettingController extends ApplicationController {
  static targets = ['radio', 'warning'];
  static values = { initial: String };

  declare readonly radioTargets: HTMLInputElement[];
  declare readonly warningTarget: HTMLElement;
  declare readonly hasWarningTarget: boolean;
  declare readonly initialValue: string;

  connect() {
    this.displayWarning();
    this.on('change', () => this.displayWarning());
  }

  private displayWarning() {
    if (!this.hasWarningTarget) return;

    const checked = this.radioTargets.find((radio) => radio.checked);
    toggle(this.warningTarget, (checked?.value ?? '') !== this.initialValue);
  }
}
