import { ApplicationController } from './application_controller';

/**
 * Generic drag & drop controller
 * Supports both integrated (input inside drop zone) and remote (input elsewhere) modes
 *
 * Usage:
 *   Integrated:  <div data-controller="drop-target">
 *                  <input type="file">
 *                </div>
 *
 *   Remote:      <textarea data-controller="drop-target"
 *                          data-drop-target-input-selector-value="#file-123">
 *                </textarea>
 *                <input type="file" id="file-123" hidden>
 */
export class DropTargetController extends ApplicationController {
  static values = {
    inputSelector: String // Optional: CSS selector for remote input
  };

  declare inputSelectorValue: string;
  declare hasInputSelectorValue: boolean;

  /**
   * Find the file input
   * - If inputSelector value exists, search in document (remote mode)
   * - Otherwise search within this.element (integrated mode)
   */
  get input(): HTMLInputElement | null {
    if (this.hasInputSelectorValue) {
      return document.querySelector<HTMLInputElement>(this.inputSelectorValue);
    }
    return this.element.querySelector<HTMLInputElement>('input[type="file"]');
  }

  /**
   * Open native file picker
   */
  openFilePicker(event: Event) {
    event.preventDefault();
    this.input?.click();
  }

  /**
   * Handle drag over - add active state
   */
  onDragOver(event: DragEvent) {
    event.preventDefault();
    this.element.classList.add('attachment-drop-zone--active');
  }

  /**
   * Handle drag leave - remove active state
   */
  onDragLeave(event: DragEvent) {
    // Only remove if leaving the drop zone entirely (not entering a child)
    if (!this.element.contains(event.relatedTarget as Node)) {
      this.element.classList.remove('attachment-drop-zone--active');
    }
  }

  /**
   * Handle drop - transfer files to input
   */
  onDrop(event: DragEvent) {
    event.preventDefault();
    this.element.classList.remove('attachment-drop-zone--active');

    const input = this.input;
    if (!input || !event.dataTransfer?.files.length) return;

    // Transfer all dropped files to the input
    const dt = new DataTransfer();
    for (const file of event.dataTransfer.files) {
      dt.items.add(file);
    }
    input.files = dt.files;

    // Dispatch change event (autosave will handle validation/upload)
    input.dispatchEvent(new Event('change', { bubbles: true }));
  }
}
