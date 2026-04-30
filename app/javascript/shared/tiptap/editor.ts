import Document from '@tiptap/extension-document';
import Hystory from '@tiptap/extension-history';
import TextAlign from '@tiptap/extension-text-align';
import Gapcursor from '@tiptap/extension-gapcursor';

import Paragraph from '@tiptap/extension-paragraph';
import BulletList from '@tiptap/extension-bullet-list';
import OrderedList from '@tiptap/extension-ordered-list';
import ListItem from '@tiptap/extension-list-item';

import Text from '@tiptap/extension-text';
import Highlight from '@tiptap/extension-highlight';
import Underline from '@tiptap/extension-underline';
import Bold from '@tiptap/extension-bold';
import Italic from '@tiptap/extension-italic';
import Strike from '@tiptap/extension-strike';
import Mention from '@tiptap/extension-mention';
import Typography from '@tiptap/extension-typography';
import Heading from '@tiptap/extension-heading';
import Link from '@tiptap/extension-link';

import {
  Editor,
  Extension,
  type EditorOptions,
  type JSONContent,
  type Extensions
} from '@tiptap/core';

import { DocumentWithHeader, Title, Header, HeaderColumn } from './nodes';
import { createSuggestionMenu, type TagSchema } from './tags';

const SingleLineDocument = Document.extend({
  content: 'block'
});

const SingleLine = Extension.create({
  name: 'singleLine',
  addKeyboardShortcuts() {
    return {
      Enter: () => true, // block keys
      'Shift-Enter': () => true
    };
  }
});

export function createEditor({
  editorElement,
  content,
  tags,
  buttons,
  attributes,
  singleLine = false,
  onChange
}: {
  editorElement: Element;
  content?: JSONContent;
  tags: TagSchema[];
  buttons: string[];
  onChange(change: { editor: Editor }): void;
  attributes?: Record<string, string>;
  singleLine?: boolean;
}): Editor {
  const options = getEditorOptions(
    editorElement,
    tags,
    buttons,
    content,
    attributes,
    singleLine
  );
  const editor = new Editor(options);
  editor.on('transaction', onChange);
  return editor;
}

function getEditorOptions(
  element: Element,
  tags: TagSchema[],
  actions: string[],
  content?: JSONContent,
  attributes?: Record<string, string>,
  singleLine = false
): Partial<EditorOptions> {
  const extensions: Extensions = [];
  for (const action of actions) {
    switch (action) {
      case 'bold':
        extensions.push(Bold);
        break;
      case 'italic':
        extensions.push(Italic);
        break;
      case 'underline':
        extensions.push(Underline);
        break;
      case 'strike':
        extensions.push(Strike);
        break;
      case 'highlight':
        extensions.push(Highlight);
        break;
      case 'bulletList':
        extensions.push(BulletList);
        break;
      case 'orderedList':
        extensions.push(OrderedList);
        break;
      case 'title':
        extensions.push(Header, HeaderColumn, Title);
        break;
      case 'link':
        extensions.push(
          Link.configure({
            openOnClick: false,
            HTMLAttributes: {
              target: '_blank',
              rel: 'noopener noreferrer'
            }
          })
        );
        break;
    }
  }

  if (actions.includes('bulletList') || actions.includes('orderedList')) {
    extensions.push(ListItem);
  }

  if (actions.includes('heading2') || actions.includes('heading3')) {
    extensions.push(Heading.configure({ levels: [2, 3] }));
  }

  if (
    actions.includes('left') ||
    actions.includes('center') ||
    actions.includes('right') ||
    actions.includes('justify')
  ) {
    extensions.push(
      TextAlign.configure({
        types: actions.includes('title')
          ? ['headerColumn', 'title', 'heading', 'paragraph']
          : ['heading', 'paragraph']
      })
    );
  }

  if (tags.length > 0) {
    extensions.push(
      Mention.configure({
        renderLabel({ node }) {
          return node.attrs.label;
        },
        HTMLAttributes: {
          class: 'fr-tag fr-tag--sm'
        },
        suggestion: createSuggestionMenu(tags, element)
      })
    );
  }

  const documentExtension = singleLine
    ? SingleLineDocument
    : actions.includes('title')
      ? DocumentWithHeader
      : Document;

  return {
    element,
    content,
    editorProps: { attributes },
    extensions: [
      documentExtension,
      Hystory,
      Typography,
      Gapcursor,
      Paragraph,
      Text,
      ...(singleLine ? [SingleLine] : []),
      ...extensions
    ]
  };
}
