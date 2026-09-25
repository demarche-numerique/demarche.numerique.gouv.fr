import { describe, expect, it } from 'vitest';
import type { Editor, JSONContent } from '@tiptap/core';

import { getAction } from './actions';
import { blockTagsAllowed } from './block_tags';
import { createEditor } from './editor';
import { createSuggestionMenu, type TagSchema } from './tags';

const tags: TagSchema[] = [
  { id: 'dossier_number', label: 'numéro du dossier' },
  { id: 'tdc1', label: 'Langages', block: true }
];

const mention = (id: string, label: string) => ({
  type: 'mention',
  attrs: { id, label }
});
const text = (text: string) => ({ type: 'text', text });

function setup(content: JSONContent[]) {
  const element = document.createElement('div');
  document.body.appendChild(element);

  const editor = createEditor({
    editorElement: element,
    content: { type: 'doc', content },
    tags,
    buttons: ['bold', 'heading2'],
    onChange: () => {}
  });

  return {
    editor,
    element,
    teardown: () => {
      editor.destroy();
      element.remove();
    }
  };
}

function suggestions(editor: Editor, element: Element) {
  const { items } = createSuggestionMenu(tags, element);
  return (items?.({ query: '', editor }) as TagSchema[])
    .map((t) => t.label)
    .sort();
}

describe('block tags guard', () => {
  it('does not offer block tags inside a heading', () => {
    const { editor, element, teardown } = setup([
      { type: 'heading', attrs: { level: 2 }, content: [text('Titre')] },
      { type: 'paragraph', content: [text('Texte')] }
    ]);

    editor.commands.setTextSelection(2);
    expect(blockTagsAllowed(editor.state)).toBe(false);
    expect(suggestions(editor, element)).toEqual(['numéro du dossier']);

    editor.commands.setTextSelection(9);
    expect(blockTagsAllowed(editor.state)).toBe(true);
    expect(suggestions(editor, element)).toEqual([
      'Langages',
      'numéro du dossier'
    ]);

    teardown();
  });

  it('rejects turning a paragraph holding a block tag into a heading', () => {
    const { editor, teardown } = setup([
      {
        type: 'paragraph',
        content: [text('Avant '), mention('tdc1', 'Langages')]
      }
    ]);

    editor.commands.setTextSelection(2);
    editor.commands.toggleHeading({ level: 2 });

    expect(editor.getJSON().content?.[0].type).toBe('paragraph');

    teardown();
  });

  it('still turns a paragraph holding an inline tag into a heading', () => {
    const { editor, teardown } = setup([
      {
        type: 'paragraph',
        content: [text('N° '), mention('dossier_number', 'numéro du dossier')]
      }
    ]);

    editor.commands.setTextSelection(2);
    editor.commands.toggleHeading({ level: 2 });

    expect(editor.getJSON().content?.[0].type).toBe('heading');

    teardown();
  });

  it('disables the heading button on a paragraph holding a block tag', () => {
    const { editor, teardown } = setup([
      {
        type: 'paragraph',
        content: [text('Avant '), mention('tdc1', 'Langages')]
      },
      { type: 'paragraph', content: [text('Texte')] }
    ]);
    const button = document.createElement('button');
    button.dataset.tiptapAction = 'heading2';

    editor.commands.setTextSelection(2);
    expect(getAction(editor, button).isDisabled()).toBe(true);

    editor.commands.setTextSelection(12);
    expect(getAction(editor, button).isDisabled()).toBe(false);

    teardown();
  });

  it('strips marks applied to a block tag', () => {
    const { editor, teardown } = setup([
      {
        type: 'paragraph',
        content: [text('Avant '), mention('tdc1', 'Langages')]
      }
    ]);

    editor.commands.selectAll();
    editor.commands.toggleBold();

    expect(editor.getJSON().content?.[0].content).toEqual([
      { type: 'text', text: 'Avant ', marks: [{ type: 'bold' }] },
      mention('tdc1', 'Langages')
    ]);

    teardown();
  });
});
