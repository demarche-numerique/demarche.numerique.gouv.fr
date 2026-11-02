import { describe, expect, it } from 'vite-plus/test';

import { getAction } from './actions';
import { createEditor } from './editor';

describe('paragraph action', () => {
  it('splits the current block into a new paragraph like the Enter key', () => {
    const element = document.createElement('div');
    document.body.appendChild(element);

    const editor = createEditor({
      editorElement: element,
      content: {
        type: 'doc',
        content: [
          { type: 'paragraph', content: [{ type: 'text', text: 'Bonjour' }] }
        ]
      },
      tags: [],
      buttons: ['paragraph'],
      onChange: () => {}
    });

    editor.commands.setTextSelection(4);

    const button = document.createElement('button');
    button.dataset.tiptapAction = 'paragraph';
    getAction(editor, button).run();

    expect(editor.getJSON().content).toEqual([
      { type: 'paragraph', content: [{ type: 'text', text: 'Bon' }] },
      { type: 'paragraph', content: [{ type: 'text', text: 'jour' }] }
    ]);

    editor.destroy();
    element.remove();
  });
});
