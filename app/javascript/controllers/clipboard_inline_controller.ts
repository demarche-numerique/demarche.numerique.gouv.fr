import { Controller } from '@hotwired/stimulus';

const RESTORE_DELAY_MS = 4000;

/**
 * Copy a string by activating a button, replaced by a success feedback, then restore initial state.
 * This is a different behavior then clipboard2 which use a dedicated button after the copied string.
 *
 * Values:
 * - text: string to copy to clipboard
 * - copiedText: feedback text shown after copy
 *
 * Targets:
 * - label: the clickable element — its text, fr-icon-* class and color are swapped on copy
 * - liveRegion: sr-only aria-live element for screen reader announcement
 *
 * Restores initial state after 4 seconds.
 */
export class ClipboardInlineController extends Controller {
  static values = {
    toCopy: String,
    copiedText: String
  };

  static targets = ['label', 'liveRegion'];

  declare readonly toCopyValue: string;
  declare readonly copiedTextValue: string;
  declare readonly labelTarget: HTMLElement;
  declare readonly liveRegionTarget: HTMLElement;

  private initialText = '';
  private initialClassName = '';
  private restoreTimer?: ReturnType<typeof setTimeout>;

  connect(): void {
    if (!navigator.clipboard) {
      this.element.remove();
      return;
    }

    const label = this.labelTarget;
    this.initialText = label.textContent ?? '';
    this.initialClassName = label.className;
  }

  disconnect(): void {
    clearTimeout(this.restoreTimer);
  }

  copy(e: Event): void {
    e.preventDefault();
    e.stopPropagation();

    if (!document.hasFocus()) return;

    void navigator.clipboard.writeText(this.toCopyValue).then(() => {
      const label = this.labelTarget;
      label.textContent = this.copiedTextValue;

      label.className = label.className.replace(
        /fr-icon-[\w-]+/,
        'fr-icon-check-line'
      );

      label.style.color = 'var(--text-default-success)';

      this.liveRegionTarget.textContent = this.copiedTextValue;

      clearTimeout(this.restoreTimer);
      this.restoreTimer = setTimeout(() => this.restore(), RESTORE_DELAY_MS);
    });
  }

  private restore(): void {
    const label = this.labelTarget;
    label.textContent = this.initialText;
    label.className = this.initialClassName;
    label.style.color = '';
    this.liveRegionTarget.textContent = '';
  }
}
