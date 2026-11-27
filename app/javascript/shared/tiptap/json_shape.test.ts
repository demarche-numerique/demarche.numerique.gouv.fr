import { afterEach, describe, expect, it } from 'vite-plus/test';
import type { Editor, JSONContent } from '@tiptap/core';

import { createEditor } from './editor';

// Documents are stored and read back by the server (TiptapService, Typst,
// export templates, referentiel URLs): a TipTap upgrade must not change the
// JSON they are saved as, which these snapshots pin down.

const ATTESTATION_BUTTONS = [
  'title',
  'heading2',
  'heading3',
  'bold',
  'italic',
  'underline',
  'highlight',
  'bulletList',
  'orderedList',
  'left',
  'center',
  'right',
  'justify',
  'undo',
  'redo',
  'hardBreak',
  'paragraph',
  'link',
  'pageBreak'
];

const MAIL_BUTTONS = [
  'bold',
  'italic',
  'heading2',
  'heading3',
  'bulletList',
  'orderedList',
  'hardBreak',
  'paragraph',
  'link'
];

const TAGS = [
  {
    id: 'dossier_number',
    label: 'numéro du dossier',
    mandatory: true,
    conditional: false
  }
];

const mention = (id: string, label: string) => ({
  type: 'mention',
  attrs: { id, label }
});

const ATTESTATION_DEFAULT: JSONContent = {
  type: 'doc',
  content: [
    {
      type: 'header',
      content: [
        {
          type: 'headerColumn',
          content: [
            {
              type: 'paragraph',
              attrs: { textAlign: 'left' },
              content: [mention('dossier_service_name', 'nom du service')]
            }
          ]
        },
        {
          type: 'headerColumn',
          content: [
            {
              type: 'paragraph',
              attrs: { textAlign: 'left' },
              content: [
                { text: 'Fait le ', type: 'text' },
                mention('dossier_processed_at', 'date de décision')
              ]
            }
          ]
        }
      ]
    },
    {
      type: 'title',
      attrs: { textAlign: 'center' },
      content: [{ text: 'Titre de l’attestation', type: 'text' }]
    },
    {
      type: 'paragraph',
      attrs: { textAlign: 'left' },
      content: [{ text: 'Vous pouvez éditer ce texte.', type: 'text' }]
    }
  ]
};

const MAIL_BODY: JSONContent = {
  type: 'doc',
  content: [
    {
      type: 'paragraph',
      content: [
        { type: 'text', text: 'Bonjour,' },
        { type: 'hardBreak' },
        { type: 'text', text: 'Votre dossier n° ' },
        mention('dossier_number', 'numéro du dossier'),
        { type: 'text', marks: [{ type: 'bold' }], text: ' a été déposé' }
      ]
    },
    {
      type: 'bulletList',
      content: [
        {
          type: 'listItem',
          content: [
            { type: 'paragraph', content: [{ type: 'text', text: 'un' }] }
          ]
        }
      ]
    },
    {
      type: 'orderedList',
      attrs: { start: 1 },
      content: [
        {
          type: 'listItem',
          content: [
            { type: 'paragraph', content: [{ type: 'text', text: 'deux' }] }
          ]
        }
      ]
    }
  ]
};

const SUBJECT: JSONContent = {
  type: 'doc',
  content: [
    {
      type: 'paragraph',
      content: [
        { type: 'text', text: 'Dossier ' },
        mention('dossier_number', 'numéro du dossier')
      ]
    }
  ]
};

let editor: Editor | undefined;
let element: HTMLElement | undefined;

function mount(
  buttons: string[],
  content: JSONContent,
  singleLine = false
): Editor {
  element = document.createElement('div');
  document.body.appendChild(element);
  editor = createEditor({
    editorElement: element,
    content,
    tags: TAGS,
    buttons,
    singleLine,
    onChange: () => {}
  });
  return editor;
}

afterEach(() => {
  editor?.destroy();
  element?.remove();
  editor = element = undefined;
});

function run(e: Editor, steps: Array<(c: Editor['commands']) => boolean>) {
  steps.forEach((step, i) => {
    expect(step(e.commands), `step ${i}`).toBe(true);
  });
}

// Position at the end of the last textblock.
const end = (e: Editor) => e.state.doc.content.size - 1;

function select(e: Editor, text: string): boolean {
  let range: { from: number; to: number } | undefined;
  e.state.doc.descendants((node, pos) => {
    const index = range || !node.text ? -1 : node.text.indexOf(text);
    if (index >= 0) {
      range = { from: pos + index, to: pos + index + text.length };
    }
  });
  return range ? e.commands.setTextSelection(range) : false;
}

describe('stored JSON shape', () => {
  it('loads the default attestation', () => {
    expect(
      mount(ATTESTATION_BUTTONS, ATTESTATION_DEFAULT).getJSON()
    ).toMatchSnapshot();
  });

  it('loads a mail body', () => {
    expect(mount(MAIL_BUTTONS, MAIL_BODY).getJSON()).toMatchSnapshot();
  });

  it('loads a single line subject', () => {
    expect(mount([], SUBJECT, true).getJSON()).toMatchSnapshot();
  });

  it('builds every attestation node and mark through commands', () => {
    const e = mount(ATTESTATION_BUTTONS, ATTESTATION_DEFAULT);
    run(e, [
      (c) => c.setTextSelection(end(e)),
      (c) => c.splitBlock(),
      (c) => c.insertContent('Titre deux'),
      (c) => c.toggleHeading({ level: 2 }),
      (c) => c.splitBlock(),
      (c) => c.insertContent('Titre trois'),
      (c) => c.toggleHeading({ level: 3 }),
      (c) => c.splitBlock(),
      (c) => c.insertContent('gras'),
      () => select(e, 'gras'),
      (c) => c.toggleBold(),
      (c) => c.setTextSelection(end(e)),
      (c) => c.unsetBold(),
      (c) => c.splitBlock(),
      (c) => c.insertContent('mix'),
      () => select(e, 'mix'),
      (c) => c.toggleItalic(),
      (c) => c.toggleUnderline(),
      (c) => c.toggleHighlight(),
      (c) => c.setLink({ href: 'https://example.com' }),
      (c) => c.setTextAlign('justify'),
      (c) => c.setTextSelection(end(e)),
      (c) => c.unsetAllMarks(),
      (c) => c.setHardBreak(),
      (c) => c.insertContent([mention('dossier_number', 'numéro du dossier')]),
      (c) => c.splitBlock(),
      (c) => c.insertContent('puce'),
      (c) => c.toggleBulletList(),
      (c) => c.splitListItem('listItem'),
      (c) => c.insertContent('sous-puce'),
      (c) => c.sinkListItem('listItem'),
      (c) => c.splitListItem('listItem'),
      (c) => c.liftListItem('listItem'),
      (c) => c.liftListItem('listItem'),
      (c) => c.insertContent('numéro'),
      (c) => c.toggleOrderedList(),
      (c) => c.splitListItem('listItem'),
      (c) => c.liftListItem('listItem'),
      (c) => c.insertContent({ type: 'pageBreak' }),
      (c) =>
        c.insertContentAt(e.state.doc.content.size, {
          type: 'paragraph',
          content: [{ type: 'text', text: 'fin' }]
        }),
      () => select(e, 'fin'),
      (c) => c.setTextAlign('right')
    ]);

    expect(e.getJSON()).toMatchSnapshot();
  });

  it('builds a mail body through commands', () => {
    const e = mount(MAIL_BUTTONS, { type: 'doc', content: [] });
    run(e, [
      (c) => c.insertContent('Bonjour '),
      (c) => c.insertContent([mention('dossier_number', 'numéro du dossier')]),
      (c) => c.splitBlock(),
      (c) => c.insertContent('lien'),
      () => select(e, 'lien'),
      (c) => c.setLink({ href: 'https://example.com' }),
      (c) => c.toggleBold()
    ]);

    expect(e.getJSON()).toMatchSnapshot();
  });
});
