import { ApplicationController } from './application_controller';

// A link annotation is edited in a draft input that does not autosave: only
// « Enregistrer » copies it into the hidden value. The server decides the state
// after a save (link shown, or input with its error) through the editing value.
export class LinkAnnotationController extends ApplicationController {
  static targets = ['display', 'editButton', 'form', 'draft', 'value'];
  static values = { editing: Boolean };

  declare readonly hasDisplayTarget: boolean;
  declare readonly displayTarget: HTMLElement;
  declare readonly hasEditButtonTarget: boolean;
  declare readonly editButtonTarget: HTMLButtonElement;
  declare readonly formTarget: HTMLElement;
  declare readonly draftTarget: HTMLInputElement;
  declare readonly valueTarget: HTMLInputElement;
  declare editingValue: boolean;

  editingValueChanged() {
    this.toggle();
  }

  edit() {
    this.editingValue = true;
    this.toggle(); // the value callback runs later: show the input before focusing it
    this.draftTarget.focus();
  }

  cancel() {
    this.draftTarget.value = this.valueTarget.value;
    this.editingValue = false;
    this.toggle();
  }

  private toggle() {
    const hadFocus = this.formTarget.contains(document.activeElement);
    if (this.hasDisplayTarget) {
      this.displayTarget.hidden = this.editingValue;
    }
    this.formTarget.hidden = !this.editingValue;
    // the focused button is now hidden: hand the focus back to « Modifier le lien »
    if (!this.editingValue && hadFocus && this.hasEditButtonTarget) {
      this.editButtonTarget.focus();
    }
  }

  save(event: Event) {
    event.preventDefault();
    if (
      this.draftTarget.value == this.valueTarget.value &&
      this.hasDisplayTarget
    ) {
      this.cancel();
      return;
    }
    this.valueTarget.value = this.draftTarget.value;
    this.valueTarget.dispatchEvent(new Event('change', { bubbles: true }));
  }

  // keep the draft out of the autosave
  isolate(event: Event) {
    event.stopPropagation();
  }
}
