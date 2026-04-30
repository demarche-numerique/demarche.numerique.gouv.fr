import { Editor } from '@tiptap/core';
import { isButtonElement, isHTMLElement } from 'coldwired/utils';
import * as s from 'superstruct';

import { getAction } from '../../shared/tiptap/actions';
import { createEditor } from '../../shared/tiptap/editor';
import { tagSchema, type TagSchema } from '../../shared/tiptap/tags';
import { httpRequest } from '../../shared/utils';
import { ApplicationController } from '../application_controller';

declare const window: Window &
  typeof globalThis & { dsfr?: (el: HTMLElement) => { modal: unknown } };

export class TiptapController extends ApplicationController {
  static targets = [
    'editor',
    'input',
    'button',
    'tag',
    'linkModal',
    'linkUrlInput',
    'linkErrorText',
    'linkSelectedText',
    'linkFormContent',
    'linkInputGroup',
    'linkConfirmButton',
    'removeLinkButton'
  ];
  static values = {
    insertAfterTag: { type: String, default: '' },
    attributes: { type: Object, default: {} },
    previewUrl: { type: String, default: '' },
    singleLine: { type: Boolean, default: false }
  };

  declare editorTarget: Element;
  declare inputTarget: HTMLInputElement;
  declare buttonTargets: HTMLButtonElement[];
  declare tagTargets: HTMLElement[];
  declare insertAfterTagValue: string;
  declare attributesValue: Record<string, string>;
  declare previewUrlValue: string;
  declare singleLineValue: boolean;

  // Link modal targets (optional - not all tiptap instances have the modal)
  declare hasLinkModalTarget: boolean;
  declare linkModalTarget: HTMLDialogElement;
  declare linkUrlInputTarget: HTMLInputElement;
  declare linkErrorTextTarget: HTMLElement;
  declare linkSelectedTextTarget: HTMLElement;
  declare linkFormContentTarget: HTMLElement;
  declare linkInputGroupTarget: HTMLElement;
  declare linkConfirmButtonTarget: HTMLButtonElement;
  declare hasRemoveLinkButtonTarget: boolean;
  declare removeLinkButtonTarget: HTMLButtonElement;

  #initializing = true;
  #editor?: Editor;
  #previewTimeout?: ReturnType<typeof setTimeout>;

  connect(): void {
    if (this.singleLineValue) {
      this.editorTarget.classList.add('tiptap--single-line');
    }
    this.#editor = createEditor({
      editorElement: this.editorTarget,
      content: this.content,
      tags: this.tags,
      buttons: this.menuButtons,
      singleLine: this.singleLineValue,
      attributes: { class: 'fr-input', ...this.attributesValue },
      onChange: ({ editor }) => {
        for (const button of this.buttonTargets) {
          const action = getAction(editor, button);
          button.classList.toggle('fr-btn--secondary', !action.isActive());

          // Special handling for link button: disable when no selection and no existing link
          if (button.dataset.tiptapAction === 'link') {
            const { empty } = editor.state.selection;
            const hasExistingLink = !!editor.getAttributes('link').href;
            button.disabled = empty && !hasExistingLink;
          } else {
            button.disabled = action.isDisabled();
          }
        }

        const previousValue = this.inputTarget.value;
        const value = JSON.stringify(editor.getJSON());
        this.inputTarget.value = value;

        // Dispatch input event only if the value has changed and not during initialization
        if (this.#initializing) {
          this.#initializing = false;
        } else if (value != previousValue) {
          this.dispatch('input', { target: this.inputTarget, prefix: '' });
          this.#schedulePreview();
        }
      }
    });
  }

  disconnect(): void {
    this.#editor?.destroy();
    if (this.#previewTimeout) {
      clearTimeout(this.#previewTimeout);
    }
  }

  #schedulePreview() {
    if (!this.previewUrlValue) return;

    if (this.#previewTimeout) {
      clearTimeout(this.#previewTimeout);
    }

    this.#previewTimeout = setTimeout(() => {
      this.#updatePreview();
    }, 500);
  }

  #updatePreview() {
    const formData = new FormData();
    formData.append(this.inputTarget.name, this.inputTarget.value);

    httpRequest(this.previewUrlValue, {
      method: 'POST',
      body: formData
    }).turbo();
  }

  menuButton(event: MouseEvent) {
    if (this.#editor && isButtonElement(event.target)) {
      const action = event.target.dataset.tiptapAction;
      if (action === 'link') {
        this.openLinkModal();
      } else {
        getAction(this.#editor, event.target).run();
      }
    }
  }

  insertTag(event: MouseEvent) {
    if (this.#editor && isHTMLElement(event.target)) {
      const tag = s.create(event.target.dataset, tagSchema);
      const editor = this.#editor
        .chain()
        .focus()
        .insertContent({ type: 'mention', attrs: tag });

      if (this.insertAfterTagValue != '') {
        editor.insertContent({ type: 'text', text: this.insertAfterTagValue });
      }
      editor.run();
    }
  }

  openLinkModal() {
    if (!this.#editor || !this.hasLinkModalTarget) return;

    const { from, to, empty } = this.#editor.state.selection;
    const selectedText = empty
      ? ''
      : this.#editor.state.doc.textBetween(from, to);
    const previousUrl = this.#editor.getAttributes('link').href ?? '';

    this.#clearLinkError();
    this.linkSelectedTextTarget.textContent = selectedText || '(lien existant)';
    this.linkUrlInputTarget.value = previousUrl;

    this.linkUrlInputTarget.focus();
    this.linkUrlInputTarget.select();

    this.updateRemoveLinkButtonState();
  }

  closeLinkModal() {
    if (!this.hasLinkModalTarget) return;

    // @ts-expect-error type not enforced
    window.dsfr(this.linkModalTarget).modal.conceal();

    if (this.#editor) {
      const { to } = this.#editor.state.selection;
      const { doc } = this.#editor.state;
      const nextChar = doc.textBetween(to, Math.min(to + 1, doc.content.size));
      const chain = this.#editor
        .chain()
        .focus()
        .setTextSelection(to)
        .unsetMark('link');
      if (nextChar !== ' ') {
        chain.insertContent(' ');
      }
      chain.run();
    }
  }

  confirmLink(event: Event) {
    event.preventDefault();

    if (!this.#editor || !this.hasLinkModalTarget) return;

    const url = this.linkUrlInputTarget.value.trim();

    if (url === '') {
      this.#editor.chain().focus().extendMarkRange('link').unsetLink().run();
      this.closeLinkModal();
      return;
    }

    if (!this.#isValidUrl(url)) {
      this.#showLinkError();
      return;
    }

    this.#editor
      .chain()
      .focus()
      .extendMarkRange('link')
      .setLink({ href: url })
      .run();

    this.closeLinkModal();
  }

  clearLinkInput() {
    this.linkUrlInputTarget.value = '';
    this.linkUrlInputTarget.focus();
    this.updateRemoveLinkButtonState();
  }

  updateRemoveLinkButtonState() {
    if (!this.hasRemoveLinkButtonTarget) return;

    const hasValue = this.linkUrlInputTarget.value.trim() !== '';
    this.removeLinkButtonTarget.disabled = !hasValue;
  }

  #isValidUrl(url: string): boolean {
    return url.startsWith('https://');
  }

  #showLinkError() {
    this.linkInputGroupTarget.classList.add('fr-input-group--error');
    this.linkErrorTextTarget.classList.remove('fr-hidden');
    this.linkUrlInputTarget.setAttribute(
      'aria-describedby',
      this.linkErrorTextTarget.id || 'link-url-error'
    );
  }

  #clearLinkError() {
    this.linkInputGroupTarget.classList.remove('fr-input-group--error');
    this.linkErrorTextTarget.classList.add('fr-hidden');
    this.linkUrlInputTarget.removeAttribute('aria-describedby');
  }

  private get content() {
    const value = this.inputTarget.value;
    if (value) {
      return s.create(JSON.parse(value), jsonContentSchema);
    }
  }

  private get tags(): TagSchema[] {
    return this.tagTargets.map((tag) => s.create(tag.dataset, tagSchema));
  }

  private get menuButtons() {
    return this.buttonTargets.map(
      (menuButton) => menuButton.dataset.tiptapAction as string
    );
  }
}

const Attrs = s.record(s.string(), s.any());
const Marks = s.array(
  s.type({
    type: s.string(),
    attrs: s.optional(Attrs)
  })
);
type JSONContent = {
  type?: string;
  text?: string;
  attrs?: s.Infer<typeof Attrs>;
  marks?: s.Infer<typeof Marks>;
  content?: JSONContent[];
};
const jsonContentSchema: s.Describe<JSONContent> = s.type({
  type: s.optional(s.string()),
  text: s.optional(s.string()),
  attrs: s.optional(Attrs),
  marks: s.optional(Marks),
  content: s.lazy(() => s.optional(s.array(jsonContentSchema)))
});
